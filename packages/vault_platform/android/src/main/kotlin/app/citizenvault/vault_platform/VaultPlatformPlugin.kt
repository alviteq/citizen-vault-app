package app.citizenvault.vault_platform

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.security.keystore.UserNotAuthenticatedException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/** Native CSPRNG and Android Keystore device-envelope implementation. */
class VaultPlatformPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "secureRandom" -> secureRandom(call, result)
                "wrapDeviceKey" -> wrapDeviceKey(call, result)
                "unwrapDeviceKey" -> unwrapDeviceKey(call, result)
                "deleteDeviceKey" -> deleteDeviceKey(call, result)
                else -> result.notImplemented()
            }
        } catch (error: KeyPermanentlyInvalidatedException) {
            result.error("PLATFORM_KEY_INVALIDATED", "Device key invalidated", null)
        } catch (error: UserNotAuthenticatedException) {
            result.error("AUTH_REQUIRED", "Local authentication required", null)
        } catch (error: AEADBadTagException) {
            result.error("AUTHENTICATION_FAILED", "Device envelope rejected", null)
        } catch (error: Throwable) {
            result.error("PLATFORM_SECURITY_UNAVAILABLE", "Platform security operation failed", null)
        }
    }

    private fun secureRandom(call: MethodCall, result: MethodChannel.Result) {
        val length = call.argument<Int>("length") ?: 0
        require(length in 1..MAX_RANDOM_BYTES)
        val bytes = ByteArray(length)
        SecureRandom().nextBytes(bytes)
        result.success(bytes)
    }

    private fun wrapDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        val alias = validatedAlias(call.argument<String>("keyAlias"))
        val masterKey = call.argument<ByteArray>("masterKey") ?: error("Missing master key")
        require(masterKey.size == 32)
        val validitySeconds = call.argument<Int>("authenticationValiditySeconds") ?: 0
        require(validitySeconds in 1..3600)
        val invalidated = call.argument<Boolean>("invalidatedByBiometricEnrollment") ?: true
        val keyStore = keyStore()
        val existing = keyStore.containsAlias(alias)
        val key =
            if (existing) {
                keyStore.getKey(alias, null) as? SecretKey ?: error("Invalid device key")
            } else {
                val preferStrongBox =
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                        context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
                try {
                    generateKey(alias, validitySeconds, invalidated, preferStrongBox)
                } catch (error: StrongBoxUnavailableException) {
                    generateKey(alias, validitySeconds, invalidated, false)
                }
        }

        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            cipher.updateAAD(AAD)
            val sealed = cipher.doFinal(masterKey)
            val ciphertextLength = sealed.size - TAG_BYTES
            result.success(
                mapOf(
                    "nonce" to cipher.iv,
                    "ciphertext" to sealed.copyOfRange(0, ciphertextLength),
                    "authenticationTag" to sealed.copyOfRange(ciphertextLength, sealed.size),
                    "createdAtEpochMilliseconds" to System.currentTimeMillis(),
                    "hardwareBacked" to isHardwareBacked(key),
                ),
            )
        } catch (error: UserNotAuthenticatedException) {
            // Keep the freshly generated key so Flutter can display the
            // biometric prompt and retry within the authentication window.
            throw error
        } catch (error: Throwable) {
            if (!existing) keyStore.deleteEntry(alias)
            throw error
        } finally {
            masterKey.fill(0)
        }
    }

    private fun unwrapDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        val alias = validatedAlias(call.argument<String>("keyAlias"))
        val nonce = call.argument<ByteArray>("nonce") ?: error("Missing nonce")
        val ciphertext = call.argument<ByteArray>("ciphertext") ?: error("Missing ciphertext")
        val tag = call.argument<ByteArray>("authenticationTag") ?: error("Missing tag")
        require(nonce.size == 12 && ciphertext.size == 32 && tag.size == TAG_BYTES)
        val key = keyStore().getKey(alias, null) as? SecretKey
            ?: run {
                result.error("KEY_NOT_FOUND", "Device key not found", null)
                return
            }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(AAD)
        result.success(cipher.doFinal(ciphertext + tag))
    }

    private fun deleteDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        val alias = validatedAlias(call.argument<String>("keyAlias"))
        val keyStore = keyStore()
        if (keyStore.containsAlias(alias)) {
            keyStore.deleteEntry(alias)
        }
        result.success(null)
    }

    private fun generateKey(
        alias: String,
        validitySeconds: Int,
        invalidated: Boolean,
        strongBox: Boolean,
    ): SecretKey {
        val builder =
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(invalidated)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val authenticationTypes =
                if (invalidated) {
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                } else {
                    KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                }
            builder.setUserAuthenticationParameters(
                validitySeconds,
                authenticationTypes,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(validitySeconds)
        }
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(builder.build())
            generateKey()
        }
    }

    private fun isHardwareBacked(key: SecretKey): Boolean {
        val factory = SecretKeyFactory.getInstance(key.algorithm, ANDROID_KEYSTORE)
        val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            info.getSecurityLevel() == KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT ||
                info.getSecurityLevel() == KeyProperties.SECURITY_LEVEL_STRONGBOX
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware()
        }
    }

    private fun keyStore(): KeyStore =
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun validatedAlias(value: String?): String {
        require(value != null && ALIAS.matches(value))
        return value
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL = "citizen_vault/security"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val TAG_BITS = 128
        const val TAG_BYTES = 16
        const val MAX_RANDOM_BYTES = 1024 * 1024
        val AAD = "citizen-vault/device-envelope/v1".toByteArray(StandardCharsets.UTF_8)
        val ALIAS = Regex("^[A-Za-z0-9._-]{1,128}$")
    }
}

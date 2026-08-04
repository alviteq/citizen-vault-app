import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let privacyViewTag = 9_741_311

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard let window, window.viewWithTag(privacyViewTag) == nil else { return }
    let shield = UIView(frame: window.bounds)
    shield.tag = privacyViewTag
    shield.backgroundColor = UIColor.systemBackground
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let label = UILabel()
    label.text = "OwnKeep is locked"
    label.textAlignment = .center
    label.font = UIFont.preferredFont(forTextStyle: .headline)
    label.translatesAutoresizingMaskIntoConstraints = false
    shield.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
    ])
    window.addSubview(shield)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    window?.viewWithTag(privacyViewTag)?.removeFromSuperview()
  }
}

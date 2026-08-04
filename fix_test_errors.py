import re

def fix_file(filepath, search_str, replace_str):
    with open(filepath, 'r') as f:
        content = f.read()
    
    if search_str in content:
        content = content.replace(search_str, replace_str, 1)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")
    else:
        print(f"Pattern not found in {filepath}")

# Fix emergency_mode_screen.dart
emergency_search = """              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row("""
emergency_replace = """              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row("""
fix_file('lib/src/emergency/emergency_mode_screen.dart', emergency_search, emergency_replace)

emergency_end_search = """                    ),
                  ],
                ),
              ),
            ),"""
emergency_end_replace = """                    ),
                  ],
                ),
              ),
            ),
            ),"""
fix_file('lib/src/emergency/emergency_mode_screen.dart', emergency_end_search, emergency_end_replace)

# Fix blind_backup_destinations_screen.dart
# I will just revert blind_backup_destinations_screen.dart first to fix the mangled state.
import os
os.system("git checkout lib/src/backup/blind_backup_destinations_screen.dart")

blind_search = """              child: Column(
                children: [
                  for (var i = 0; i < BlindBackupDestinationKind.values.length; i++) ...["""
blind_replace = """              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (var i = 0; i < BlindBackupDestinationKind.values.length; i++) ...["""

def fix_blind():
    with open('lib/src/backup/blind_backup_destinations_screen.dart', 'r') as f:
        content = f.read()
    content = content.replace(blind_search, blind_replace, 1)
    
    blind_end_search = """                  ],
                ],
              ),
            ),"""
    blind_end_replace = """                  ],
                ],
              ),
            ),
            ),"""
    content = content.replace(blind_end_search, blind_end_replace, 1)
    
    with open('lib/src/backup/blind_backup_destinations_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed blind_backup_destinations_screen.dart")

fix_blind()


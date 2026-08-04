import os

with open('lib/src/intelligence/on_device_intelligence_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("${tr('Grounded Recommendations').toUpperCase()}", "${tr('Grounded Recommendations')}")

with open('lib/src/intelligence/on_device_intelligence_screen.dart', 'w') as f:
    f.write(content)

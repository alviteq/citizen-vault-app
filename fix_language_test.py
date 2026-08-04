import re

with open('lib/src/settings/language_settings_screen.dart', 'r') as f:
    content = f.read()

# Fix both containers that have Column and ListTiles
search_str = """              child: Column(
                children: ["""
replace_str = """              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: ["""

# There are two of these columns.
content = content.replace(search_str, replace_str, 2)

# Fix the closing braces for both
# The first one ends with:
end_search_1 = """                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),"""
end_replace_1 = """                  ],
                ],
              ),
              ),
            ),
            const SizedBox(height: 16),"""
content = content.replace(end_search_1, end_replace_1, 1)

# The second one ends with:
end_search_2 = """                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );"""
end_replace_2 = """                  ],
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );"""
content = content.replace(end_search_2, end_replace_2, 1)

with open('lib/src/settings/language_settings_screen.dart', 'w') as f:
    f.write(content)

print("Fixed language_settings_screen.dart")

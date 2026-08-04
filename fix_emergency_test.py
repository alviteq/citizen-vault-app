import re

with open('lib/src/emergency/emergency_mode_screen.dart', 'r') as f:
    content = f.read()

# Fix the first container
search_1 = """              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row("""
replace_1 = """              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row("""
content = content.replace(search_1, replace_1, 1)

end_search_1 = """                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),"""
end_replace_1 = """                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 16),"""
content = content.replace(end_search_1, end_replace_1, 1)

# Fix the second container
search_2 = """            for (final contact in env.contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: ListTile("""

replace_2 = """            for (final contact in env.contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile("""

content = content.replace(search_2, replace_2, 1)

end_search_2 = """                  ),
                ),
              ),"""
end_replace_2 = """                  ),
                ),
                ),
              ),"""
content = content.replace(end_search_2, end_replace_2, 1)

with open('lib/src/emergency/emergency_mode_screen.dart', 'w') as f:
    f.write(content)
print("Fixed emergency_mode_screen.dart")


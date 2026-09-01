import sys

filepath = 'lib/screens/home/home_portfolio_repository.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace(
    'return _filterSection(',
    'return await _filterSection('
)

with open(filepath, 'w') as f:
    f.write(content)

import markdown
from weasyprint import HTML
import os

# 读取 Markdown 文件
with open('submission-file.md', 'r', encoding='utf-8') as f:
    markdown_content = f.read()

# 将 Markdown 转换为 HTML
html_content = markdown.markdown(markdown_content)

# 添加基本的 CSS 样式
html_content = f'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 40px;
        }}
        h1 {{
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }}
        h2 {{
            color: #444;
            margin-top: 30px;
        }}
        a {{
            color: #0066cc;
            text-decoration: none;
        }}
        a:hover {{
            text-decoration: underline;
        }}
    </style>
</head>
<body>
{html_content}
</body>
</html>
'''

# 生成 PDF
HTML(string=html_content).write_pdf('submission-file.pdf') 
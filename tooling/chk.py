import os
fpath = r'c:\Users\Lenovo\develop\deviz_mvp\lib\features\jobs\lucrare_detalii_page.dart'
content = open(fpath, encoding='utf-8').read()
result = []
for i, line in enumerate(content.split(chr(10)), 1):
    for j, c in enumerate(line):
        cp = ord(c)
        if cp > 127:
            result.append(str(i) + ' U+' + format(cp,'04X') + ' ' + repr(line[max(0,j-5):j+5]))
open(r'c:\Users\Lenovo\develop\deviz_mvp\tooling\na.txt','w',encoding='utf-8').write(chr(10).join(result[:40]))
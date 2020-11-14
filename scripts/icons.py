from os import listdir, rmdir
from os.path import isfile, join
from pathlib import Path
from PIL import Image
import json
import urllib.request
import shutil
import zipfile

current_icons_path = '../CoinTicker/Assets.xcassets/Icons'
remote_icons_path = 'https://github.com/spothq/cryptocurrency-icons/archive/master.zip'
downloads_path = './downloads'
downloaded_icons_file = join(downloads_path, 'latest_icons.zip')
downloaded_icons_path = join(downloads_path, 'cryptocurrency-icons-master', '128', 'black')

print('Populating current list of icons')
current_icons = []
for f in listdir(current_icons_path):
    if f.endswith('.imageset') and len(listdir(join(current_icons_path, f))) > 0:
        current_icons.append(f.replace('_small', '').replace('.imageset', '').upper())

print('Downloading latest icons')
Path(downloads_path).mkdir(parents=True, exist_ok=True)
urllib.request.urlretrieve(remote_icons_path, downloaded_icons_file)

print('Unzipping downloaded icons')
with zipfile.ZipFile(downloaded_icons_file, 'r') as zip_ref:
    zip_ref.extractall(downloads_path)

print('Checking for new downloaded icons')
new_icons = []
for f in listdir(downloaded_icons_path):
    if (isfile(join(downloaded_icons_path, f))):
        currency = f.replace('.png', '').upper()
        if currency not in current_icons:
            original_icon = Image.open(join(downloaded_icons_path, f)).convert('RGBA')

            imageset_path = join(current_icons_path, f'{currency}_small.imageset')
            Path(imageset_path).mkdir(parents=True, exist_ok=True)
            
            icon_name = f'{currency}_small.png'
            new_icon = original_icon.resize((15, 15), Image.ANTIALIAS)
            new_icon.save(join(imageset_path, icon_name), 'PNG')

            icon_name_2x = f'{currency}_small@2x.png'
            new_icon_2x = original_icon.resize((30, 30), Image.ANTIALIAS)
            new_icon_2x.save(join(imageset_path, icon_name_2x), 'PNG')

            icon_name_3x = f'{currency}_small@3x.png'
            new_icon_3x = original_icon.resize((45, 45), Image.ANTIALIAS)
            new_icon_3x.save(join(imageset_path, icon_name_3x), 'PNG')

            with open(join(imageset_path, 'Contents.json'), 'w') as contents_file:
                json.dump({
                    'images' : [
                        {
                            'idiom' : 'universal',
                            'filename' : icon_name,
                            'scale' : '1x'
                        },
                        {
                            'idiom' : 'universal',
                            'filename' : icon_name_2x,
                            'scale' : '2x'
                        },
                        {
                            'idiom' : 'universal',
                            'filename' : icon_name_3x,
                            'scale' : '3x'
                        }
                    ],
                    'info' : {
                        'version' : 1,
                        'author' : 'xcode'
                    }
                }, contents_file)

            new_icons.append(currency)

print(f'Created {len(new_icons)} new icon(s)')

print('Removing downloaded icons')
shutil.rmtree(downloads_path, ignore_errors=True)

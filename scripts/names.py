import json
import urllib.request

req = urllib.request.Request(
    'https://web-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?convert=USD&cryptocurrency_type=all&limit=5000&sort=market_cap&sort_dir=desc',
    data=None, 
    headers={
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:82.0) Gecko/20100101 Firefox/82.0'
    },
)

names = []
with urllib.request.urlopen(req) as url:
    response = json.loads(url.read().decode())
    for item in response['data']:
        symbol = item['symbol'].lower()
        name = item['name']
        names.append(f'"currency.{symbol}.title" = "{name}";')

names.sort()
for n in names:
    print(n)

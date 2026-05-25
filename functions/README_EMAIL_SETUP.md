# Configurare email pentru `Trimite direct`

Fluxul `Trimite direct` foloseste Firebase Cloud Functions si Nodemailer.
Configurarea activa este citita mai intai din aplicatie, din colectia Firestore `email_server_configs`. Daca nu exista nicio configuratie activa in Firestore, backend-ul cade controlat pe Firebase Secrets.

## 1. Seteaza cheia de criptare pentru parolele SMTP
Ruleaza din radacina proiectului:

```powershell
firebase functions:secrets:set EMAIL_CONFIG_ENCRYPTION_KEY --project devizpro-ultra-pilot
```

Cheia trebuie sa fie un secret puternic, folosit pentru criptarea parolelor salvate din aplicatie.

## 2. Configureaza SMTP din aplicatie
In aplicatie, deschide modulul `Setari email` si completeaza:
- providerul preset sau hostul SMTP custom;
- portul si optiunea Secure / SSL;
- username si parola;
- `From email`, `From name`, `Reply-to`;
- apoi foloseste `Testeaza conexiunea`, `Trimite email test`, `Salveaza` si `Seteaza activ`.

Configuratia marcata activa devine sursa principala pentru trimiterea emailurilor din coada `notification_email_queue`.

## 3. Seteaza si fallback-ul din Firebase Secrets
Ruleaza din radacina proiectului:

```powershell
firebase functions:secrets:set NOTIFICATION_SMTP_HOST --project devizpro-ultra-pilot
firebase functions:secrets:set NOTIFICATION_SMTP_PORT --project devizpro-ultra-pilot
firebase functions:secrets:set NOTIFICATION_SMTP_USER --project devizpro-ultra-pilot
firebase functions:secrets:set NOTIFICATION_SMTP_PASS --project devizpro-ultra-pilot
firebase functions:secrets:set NOTIFICATION_EMAIL_FROM --project devizpro-ultra-pilot
firebase functions:secrets:set NOTIFICATION_SMTP_SECURE --project devizpro-ultra-pilot
```

Valori tipice:
- `NOTIFICATION_SMTP_HOST`: host SMTP, de ex. `smtp.office365.com`
- `NOTIFICATION_SMTP_PORT`: `587`
- `NOTIFICATION_SMTP_USER`: contul de trimitere
- `NOTIFICATION_SMTP_PASS`: parola sau app password
- `NOTIFICATION_EMAIL_FROM`: de ex. `DevizPro Ultra <office@example.com>`
- `NOTIFICATION_SMTP_SECURE`: `false` pentru port 587, `true` pentru port 465

## 4. Deploy Functions

```powershell
firebase deploy --only functions --project devizpro-ultra-pilot
```

## 5. Verificare
Dupa deploy:
- salveaza si activeaza o configuratie SMTP din `Setari email`;
- foloseste `Trimite direct` din oferta sau `Trimite email test` din pagina de setari;
- verifica in Firestore colectiile `notifications` si `notification_email_queue`;
- verifica si colectiile `email_server_configs` si `email_delivery_logs`;
- daca emailul esueaza, campurile `email_status`, `email_error_message` si `error_message` vor contine cauza exacta.

## 6. Fallback local
Daca Firebase cloud sau SMTP nu sunt disponibile, aplicatia cade automat pe clientul local de email si pregateste PDF-ul pentru trimitere.

## 7. Config locala optionala
Pentru teste locale poti copia `functions/.env.example` in `functions/.env` si completa valorile reale.
Firebase Secrets raman varianta recomandata pentru productie.

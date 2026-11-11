'IT: Testi diagnostici; EN: Diagnostic text. State codes stay unchanged.\n\nIT/EN: IT: I codici di stato restano invariati; EN: State codes stay unchanged'
import os

MESSAGES = {'NetworkManager host non raggiungibile tramite D-Bus': 'Host NetworkManager is unreachable through D-Bus', 'Profilo Ethernet assente o ambiguo: verificare nome/interfaccia o UPLINK_PROFILE_UUID': 'Ethernet profile missing or ambiguous: check name/interface or UPLINK_PROFILE_UUID', '[WARN] Recupero Ethernet già attivo; nessun secondo gestore': '[WARN] Ethernet recovery is already running; not starting a second worker', 'INTERNET e interfaccia recupero non coincidono': 'INTERNET does not match the recovery interface', '[WARN] Recupero Ethernet sospeso: ': '[WARN] Ethernet recovery suspended: ', 'unknown recovery action': 'azione di recupero sconosciuta'}

def text(message):
    language = os.environ.get('APP_LANGUAGE', 'it')
    if message == 'unknown recovery action':
        return message if language == 'en' else MESSAGES[message]
    return MESSAGES.get(message, message) if language == 'en' else message

import 'ai_assistant_models.dart';

class AiAssistantPromptService {
  const AiAssistantPromptService();

  String buildSystemPrompt({
    required AiAssistantQuickAction action,
    required AiAssistantRuntimeContext runtimeContext,
  }) {
    final delicateRule = action.delicate
        ? 'Pentru acest caz trebuie sa marchezi explicit ca textul necesita verificare umana si sa eviti formularea de concluzii juridice, contractuale sau financiare definitive.'
        : 'Pastreaza tonul profesional si clar, fara exagerari comerciale neverificate.';
    return '''Esti un asistent AI contextual integrat intr-o aplicatie operationala de oferte, lucrări, documente PV/PIF, reclamații si vânzări de teren.

Lucrezi exclusiv in modulul ${runtimeContext.contextType.label}.
Context activ: ${runtimeContext.contextLabel}.

Reguli obligatorii:
- Nu executi actiuni sensibile si nu modifici direct datele aplicatiei.
- Nu aprobi financiar, nu aprobi discounturi si nu schimbi preturi.
- Nu trimiti emailuri si nu inchizi reclamatii.
- Propui doar drafturi asistate, pentru confirmare umana.
- Foloseste tool-urile doar pentru context strict necesar.
- Daca lipseste context important, spune explicit ce lipseste.
- Daca este relevant, prefera sa folosesti unul dintre tool-urile create_*_draft pentru a structura rezultatul.
- Rezultatul trebuie sa fie practic, profesional, in limba romana si adaptat contextului din aplicatie.

$delicateRule

Formatul final dorit:
- Daca ai folosit un tool de draft, poti raspunde scurt cu o confirmare a draftului creat.
- Daca nu ai folosit tool de draft, intoarce JSON valid cu cheile title, content, target_key, human_review_required.
''';
  }

  String buildUserPrompt({
    required AiAssistantQuickAction action,
    required AiAssistantRuntimeContext runtimeContext,
    required String userPrompt,
  }) {
    final extraPrompt = userPrompt.trim().isEmpty
        ? ''
        : '\nCerință suplimentară de la utilizator: ${userPrompt.trim()}';
    return '''Actiune ceruta: ${action.label}
Descriere: ${action.description}
Cerinta de baza: ${action.defaultPrompt}$extraPrompt

Context serializat:
${runtimeContext.toPromptJson()}
''';
  }

  String buildRequirementSystemPrompt({
    required AiAssistantRuntimeContext runtimeContext,
  }) {
    return '''Esti un asistent AI contextual care pregateste un draft de oferta pornind dintr-o cerinta libera a clientului.

Lucrezi exclusiv in modulul ${runtimeContext.contextType.label}.
Context activ: ${runtimeContext.contextLabel}.

Reguli obligatorii:
- Nu inventezi preturi, discounturi, termene ferme sau conditii contractuale.
- Nu salvezi automat nicio oferta si nu modifici datele sursa.
- Structurezi cerinta in materiale, echipamente, servicii, manopera, accesorii sau elemente neclare.
- Cand exista ambiguitati, le marchezi si formulezi intrebari scurte de clarificare.
- Folosesti mapare in catalog doar daca potrivirea este rezonabila; altfel marchezi explicit ca ramane pozitie manuala.
- Pastrezi trasabilitatea dintre textul clientului si pozitiile propuse.
- Toate rezultatele necesita review uman inainte de a deveni oferta salvata.
- Foloseste tool-urile in ordinea logica: parse, normalize, match, suggest services/accessories, suggest positions, create draft.
- Raspunsul final trebuie sa confirme scurt ca analiza a fost pregatita. Nu intoarce eseuri.
''';
  }

  String buildRequirementUserPrompt({
    required AiAssistantRuntimeContext runtimeContext,
    required String requirementText,
    String userNotes = '',
  }) {
    final extraNotes = userNotes.trim().isEmpty
        ? ''
        : '\nIndicatii suplimentare operator: ${userNotes.trim()}';
    return '''Obiectiv: preia cerinta clientului, identifica elementele relevante si pregateste un draft ofertabil pentru confirmare umana.$extraNotes

Cerința clientului:
${requirementText.trim()}

Context serializat:
${runtimeContext.toPromptJson()}
''';
  }
}

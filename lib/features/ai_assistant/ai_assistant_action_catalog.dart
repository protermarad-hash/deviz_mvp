import 'ai_assistant_models.dart';

class AiAssistantActionCatalog {
  const AiAssistantActionCatalog._();

  static const String getOfferContextTool = 'get_offer_context';
  static const String getClientContextTool = 'get_client_context';
  static const String getJobContextTool = 'get_job_context';
  static const String getComplaintContextTool = 'get_complaint_context';
  static const String getProductContextTool = 'get_product_context';
  static const String getFieldSalesRequestContextTool =
      'get_field_sales_request_context';
  static const String getCompanyProfileContextTool =
      'get_company_profile_context';
  static const String parseCustomerRequirementTool =
      'parse_customer_requirement';
  static const String normalizeRequirementItemsTool =
      'normalize_requirement_items';
  static const String matchCatalogProductsTool = 'match_catalog_products';
  static const String suggestOfferPositionsFromRequirementTool =
      'suggest_offer_positions_from_requirement';
  static const String suggestRequiredServicesTool = 'suggest_required_services';
  static const String suggestMissingAccessoriesTool =
      'suggest_missing_accessories';
  static const String createOfferDraftFromRequirementTool =
      'create_offer_draft_from_requirement';
  static const String createOfferTextDraftTool = 'create_offer_text_draft';
  static const String createReportDraftTool = 'create_report_draft';
  static const String createEmailDraftTool = 'create_email_draft';

  static const List<AiAssistantQuickAction> _actions = <AiAssistantQuickAction>[
    AiAssistantQuickAction(
      id: 'offer_requirement_to_draft',
      contextType: AiAssistantContextType.offers,
      label: 'Oferta din cerinta client',
      description:
          'Structureaza cerinta clientului, propune pozitii si pregateste draftul de oferta.',
      defaultPrompt:
          'Analizeaza cerinta clientului, structureaza materiale, echipamente, servicii si manopera, propune mapare in catalog unde este posibil si pregateste un draft de oferta care necesita verificare umana.',
      defaultTargetKey: 'offer_requirement_draft',
      delicate: true,
      toolNames: <String>[
        getClientContextTool,
        getJobContextTool,
        getProductContextTool,
        getCompanyProfileContextTool,
        parseCustomerRequirementTool,
        normalizeRequirementItemsTool,
        matchCatalogProductsTool,
        suggestRequiredServicesTool,
        suggestMissingAccessoriesTool,
        suggestOfferPositionsFromRequirementTool,
        createOfferDraftFromRequirementTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'offer_commercial_description',
      contextType: AiAssistantContextType.offers,
      label: 'Descriere comerciala',
      description: 'Genereaza o descriere comerciala clara pentru oferta.',
      defaultPrompt:
          'Genereaza o descriere comerciala profesionista, clara si concreta pentru aceasta oferta, fara promisiuni juridice sau financiare nevalidate.',
      defaultTargetKey: 'offer_notes',
      toolNames: <String>[
        getOfferContextTool,
        getClientContextTool,
        getJobContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'offer_rephrase',
      contextType: AiAssistantContextType.offers,
      label: 'Reformuleaza oferta',
      description: 'Reface textul intr-o varianta mai clara si profesionala.',
      defaultPrompt:
          'Reformuleaza continutul ofertei intr-o varianta mai clara, mai usor de inteles pentru client si mai bine structurata.',
      defaultTargetKey: 'offer_notes',
      toolNames: <String>[
        getOfferContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'offer_email',
      contextType: AiAssistantContextType.offers,
      label: 'Email de trimitere',
      description: 'Redacteaza email comercial pentru trimiterea ofertei.',
      defaultPrompt:
          'Scrie un email comercial profesionist pentru transmiterea ofertei catre client, cu ton politicos si orientat spre clarificari.',
      toolNames: <String>[
        getOfferContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createEmailDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'complaint_finding',
      contextType: AiAssistantContextType.complaints,
      label: 'Constatare profesionala',
      description: 'Transforma notitele tehnice intr-o constatare structurata.',
      defaultPrompt:
          'Transforma notitele tehnice disponibile intr-o constatare profesionala, obiectiva si prudenta, potrivita pentru document intern sau proces-verbal.',
      defaultTargetKey: 'complaint_field_finding',
      delicate: true,
      toolNames: <String>[
        getComplaintContextTool,
        getClientContextTool,
        getProductContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'complaint_diplomatic_response',
      contextType: AiAssistantContextType.complaints,
      label: 'Raspuns diplomatic',
      description: 'Propune raspuns politicos si echilibrat pentru client.',
      defaultPrompt:
          'Formuleaza un raspuns diplomatic, prudent si profesionist pentru client, fara a face asumari juridice, financiare sau contractuale.',
      defaultTargetKey: 'complaint_internal_notes',
      delicate: true,
      toolNames: <String>[
        getComplaintContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createEmailDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'field_sales_mini_offer',
      contextType: AiAssistantContextType.fieldSales,
      label: 'Mini-oferta rapida',
      description: 'Genereaza un rezumat comercial scurt pentru teren.',
      defaultPrompt:
          'Genereaza o mini-oferta rapida, scurta si usor de prezentat clientului pe baza produselor sau serviciilor selectate.',
      defaultTargetKey: 'field_sales_request_notes',
      toolNames: <String>[
        getFieldSalesRequestContextTool,
        getClientContextTool,
        getProductContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'field_sales_product_explanation',
      contextType: AiAssistantContextType.fieldSales,
      label: 'Explica produsul',
      description: 'Explica pe intelesul clientului produsul sau pachetul.',
      defaultPrompt:
          'Explica pe intelesul clientului produsul sau varianta selectata, in limbaj comercial simplu si concret.',
      defaultTargetKey: 'field_sales_request_notes',
      toolNames: <String>[
        getFieldSalesRequestContextTool,
        getProductContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'offers_contextual_chat',
      contextType: AiAssistantContextType.offers,
      label: 'Chat liber contextual',
      description:
          'Discută liber pe contextul ofertei pentru cerințe speciale, text personalizat sau recomandări operative.',
      defaultPrompt:
          'Răspunde contextual la cerința liberă a utilizatorului. Poți propune text personalizat pentru ofertă, email, document comercial sau recomandări practice, fără a modifica automat datele și fără a lua decizii financiare ori juridice.',
      delicate: true,
      toolNames: <String>[
        getOfferContextTool,
        getClientContextTool,
        getJobContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
        createReportDraftTool,
        createEmailDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'complaints_contextual_chat',
      contextType: AiAssistantContextType.complaints,
      label: 'Chat liber contextual',
      description:
          'Discută liber pe contextul reclamației pentru excepții, răspunsuri personalizate sau recomandări.',
      defaultPrompt:
          'Răspunde contextual la cerința liberă a utilizatorului. Poți propune texte personalizate pentru constatări, răspunsuri, procese-verbale sau recomandări operative, fără a închide automat cazuri și fără concluzii juridice definitive.',
      delicate: true,
      toolNames: <String>[
        getComplaintContextTool,
        getClientContextTool,
        getJobContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
        createEmailDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'field_sales_contextual_chat',
      contextType: AiAssistantContextType.fieldSales,
      label: 'Chat liber contextual',
      description:
          'Discută liber pe contextul din teren pentru excepții, explicații și texte comerciale personalizate.',
      defaultPrompt:
          'Răspunde contextual la cerința liberă a utilizatorului. Poți propune texte comerciale, mini-oferte, explicații pentru client sau recomandări de teren, fără a modifica automat prețuri sau documente.',
      delicate: true,
      toolNames: <String>[
        getFieldSalesRequestContextTool,
        getClientContextTool,
        getProductContextTool,
        getCompanyProfileContextTool,
        createOfferTextDraftTool,
        createReportDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'job_site_material_reception_pv',
      contextType: AiAssistantContextType.jobs,
      label: 'PV recepție materiale',
      description:
          'Redactează textul pentru recepția materialelor ajunse pe lucrare pe baza anexelor și a contextului activ.',
      defaultPrompt:
          'Pe baza listei de materiale și echipamente din anexele documentului și a contextului lucrării, redactează un text profesionist pentru PV de recepție materiale. Evidențiază ce s-a recepționat, eventualele observații, starea la primire și acțiunile următoare. Nu inventa cantități care nu apar în listă.',
      defaultTargetKey: 'job_site_full_body',
      delicate: true,
      toolNames: <String>[
        getJobContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'job_site_final_reception_pv',
      contextType: AiAssistantContextType.jobs,
      label: 'PV recepție finală / PIF',
      description:
          'Redactează concluzii și sinteză pentru recepția finală sau PIF folosind toate elementele din anexele documentului.',
      defaultPrompt:
          'Pe baza tuturor elementelor din anexele documentului și a contextului lucrării, redactează textul pentru recepția finală sau PIF. Include sinteza elementelor montate/puse în funcțiune, rezultatul recepției, observațiile importante și etapa următoare. Nu omite elementele din anexă și nu inventa măsurători care nu există în context.',
      defaultTargetKey: 'job_site_full_body',
      delicate: true,
      toolNames: <String>[
        getJobContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'job_site_full_document_body',
      contextType: AiAssistantContextType.jobs,
      label: 'Corp complet PV / PIF',
      description:
          'Generează un corp complet de document și îl distribuie automat în câmpurile principale din editor.',
      defaultPrompt:
          'Generează un corp complet pentru documentul PV/PIF curent, folosind contextul lucrării și toate anexele. Răspunde strict structurat pe secțiuni, câte una pe rând, în această ordine: Titlu:, Subtitlu:, Observații:, Concluzii:, Probe:, Etapa următoare:. Completează fiecare secțiune cu text profesional și coerent. Nu inventa cantități sau probe care nu există în context.',
      defaultTargetKey: 'job_site_full_body',
      delicate: true,
      toolNames: <String>[
        getJobContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
      ],
    ),
    AiAssistantQuickAction(
      id: 'jobs_contextual_chat',
      contextType: AiAssistantContextType.jobs,
      label: 'Chat liber contextual',
      description:
          'Discută liber pe contextul lucrării și al documentului PV/PIF pentru excepții, documente personalizate sau sfaturi.',
      defaultPrompt:
          'Răspunde contextual la cerința liberă a utilizatorului. Poți propune PV-uri, PIF-uri, note de recepție, documente personalizate sau sfaturi operative pe baza contextului lucrării și a anexelor, fără a modifica automat datele și fără concluzii juridice definitive.',
      delicate: true,
      toolNames: <String>[
        getJobContextTool,
        getClientContextTool,
        getCompanyProfileContextTool,
        createReportDraftTool,
        createOfferTextDraftTool,
        createEmailDraftTool,
      ],
    ),
  ];

  static List<AiAssistantQuickAction> actionsFor(
    AiAssistantContextType type,
  ) {
    return _actions
        .where((item) => item.contextType == type)
        .toList(growable: false);
  }

  static AiAssistantQuickAction? actionById(String actionId) {
    for (final item in _actions) {
      if (item.id == actionId) {
        return item;
      }
    }
    return null;
  }

  static List<AiAssistantToolDefinition> toolsForAction(
    AiAssistantQuickAction action,
  ) {
    return action.toolNames
        .map(toolByName)
        .whereType<AiAssistantToolDefinition>()
        .toList(growable: false);
  }

  static AiAssistantToolDefinition? toolByName(String toolName) {
    for (final tool in safeTools) {
      if (tool.name == toolName) {
        return tool;
      }
    }
    return null;
  }

  static const List<AiAssistantToolDefinition> safeTools =
      <AiAssistantToolDefinition>[
    AiAssistantToolDefinition(
      name: getOfferContextTool,
      description:
          'Obtine contextul strict necesar al unei oferte active, fara a modifica datele.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'offer_id': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getClientContextTool,
      description:
          'Obtine contextul clientului legat de entitatea curenta, doar pentru redactare.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'client_id': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getJobContextTool,
      description:
          'Obtine contextul lucrarii asociate, fara modificari operationale.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'job_id': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getComplaintContextTool,
      description:
          'Obtine contextul reclamatiei sau al interventiei pentru redactare asistata.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'complaint_id': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getProductContextTool,
      description:
          'Obtine contextul produsului sau al produselor relevante pentru explicare comerciala.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'product_id': <String, dynamic>{'type': 'string'},
          'include_selected_products': <String, dynamic>{'type': 'boolean'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getFieldSalesRequestContextTool,
      description:
          'Obtine contextul cererii comerciale sau al lead-ului din teren, fara actiuni automate.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'request_id': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: getCompanyProfileContextTool,
      description:
          'Obtine datele publice si comerciale de baza ale companiei pentru ton si semnatura.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    AiAssistantToolDefinition(
      name: parseCustomerRequirementTool,
      description:
          'Parseaza cerinta clientului in itemi structurati, fara a crea direct documente sau preturi.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['items'],
        'properties': <String, dynamic>{
          'original_requirement': <String, dynamic>{'type': 'string'},
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'id': <String, dynamic>{'type': 'string'},
                'source_text': <String, dynamic>{'type': 'string'},
                'normalized_name': <String, dynamic>{'type': 'string'},
                'category': <String, dynamic>{'type': 'string'},
                'unit_of_measure': <String, dynamic>{'type': 'string'},
                'quantity': <String, dynamic>{'type': 'number'},
                'technical_specs': <String, dynamic>{'type': 'string'},
                'brand': <String, dynamic>{'type': 'string'},
                'model': <String, dynamic>{'type': 'string'},
                'notes': <String, dynamic>{'type': 'string'},
                'confidence': <String, dynamic>{'type': 'number'},
                'needs_review': <String, dynamic>{'type': 'boolean'},
                'suggested_questions': <String, dynamic>{
                  'type': 'array',
                  'items': <String, dynamic>{'type': 'string'},
                },
                'flags': <String, dynamic>{
                  'type': 'array',
                  'items': <String, dynamic>{'type': 'string'},
                },
              },
            },
          },
          'clarification_questions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
          'warnings': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: normalizeRequirementItemsTool,
      description:
          'Normalizeaza denumirile, unitatile si categoriile itemilor extrasi din cerinta.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['items'],
        'properties': <String, dynamic>{
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: matchCatalogProductsTool,
      description:
          'Mapeaza itemii de tip material, echipament sau accesoriu la produse existente in catalog, unde exista potriviri.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['items'],
        'properties': <String, dynamic>{
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: suggestRequiredServicesTool,
      description:
          'Propune servicii sau manopera necesare pentru itemii identificati, fara asumare de pret.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
          'service_suggestions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: suggestMissingAccessoriesTool,
      description:
          'Propune accesorii sau materiale complementare probabile care trebuie verificate de operator.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
          'accessory_suggestions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: suggestOfferPositionsFromRequirementTool,
      description:
          'Compune pozitiile propuse pentru draftul de oferta pe baza itemilor si a maparii la catalog.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['positions'],
        'properties': <String, dynamic>{
          'positions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: createOfferDraftFromRequirementTool,
      description:
          'Pregateste payload-ul unui draft de oferta derivat din cerinta clientului, doar pentru confirmare umana.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'draft_title': <String, dynamic>{'type': 'string'},
          'draft_notes': <String, dynamic>{'type': 'string'},
          'positions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
          'clarification_questions': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
          'warnings': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
        },
      },
    ),
    AiAssistantToolDefinition(
      name: createOfferTextDraftTool,
      description:
          'Construieste un draft asistat pentru oferta, fara a-l salva automat in entitate.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['title', 'content'],
        'properties': <String, dynamic>{
          'title': <String, dynamic>{'type': 'string'},
          'content': <String, dynamic>{'type': 'string'},
          'target_key': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: createReportDraftTool,
      description:
          'Construieste un draft de constatare sau raport, doar pentru review uman.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['title', 'content'],
        'properties': <String, dynamic>{
          'title': <String, dynamic>{'type': 'string'},
          'content': <String, dynamic>{'type': 'string'},
          'target_key': <String, dynamic>{'type': 'string'},
        },
      },
    ),
    AiAssistantToolDefinition(
      name: createEmailDraftTool,
      description:
          'Construieste un draft de email asistat, fara a trimite emailul automat.',
      parameters: <String, dynamic>{
        'type': 'object',
        'required': <String>['title', 'content'],
        'properties': <String, dynamic>{
          'title': <String, dynamic>{'type': 'string'},
          'content': <String, dynamic>{'type': 'string'},
          'target_key': <String, dynamic>{'type': 'string'},
        },
      },
    ),
  ];
}

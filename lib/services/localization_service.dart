class Localization {
  static String currentLanguage = 'en';

  static const Map<String, Map<String, String>> _data = {
    'en': {
      'hub_title': 'AMANA SDK',
      'hub_subtitle': 'AINIMONIA Authoring Tools',
      'sync_btn': 'START SYNC',
      'syncing_btn': 'SYNCHRONIZING...',
      'change_path': 'CHANGE',
      'settings': 'Project Settings',
      'git_token': 'GitHub Secret Token',
      'git_desc':
          'Hey there! We use Git to keep the project in sync. Paste your Personal Access Token (PAT) below.',
      'git_tip_title': 'PRO TIP 💡',
      'git_help': 'You need a "Classic Token" with the "repo" scope enabled.',
      'git_link_text': 'GENERATE TOKEN ON GITHUB',
      'footer_info':
          'All assets will be synced with the AINIMONIA master branch.',
      'desc_project': 'The core of AINIMONIA. Keep it updated!',
      'desc_godot': 'Godot 4.6 Stable - Our engine of choice.',
      'desc_trench': 'Trenchbroom Fork + LiveSync bridge.',
      'desc_block': 'Blockbench Fork + Entity Templates.',
      'desc_blender': 'Blender 4.5.6 LTS - Modeling, sculpting and animation',
      'desc_matmaker': 'MATMAKER - Material Maker fork for Godot materials.',
      'studio_top_category': 'MAIN',
      'studio_tools_category': 'TOOLS',
    },
    'pt': {
      'hub_title': 'AMANA SDK',
      'hub_subtitle': 'Ferramentas de Autoria AINIMONIA',
      'sync_btn': 'SINCRONIZAR',
      'syncing_btn': 'SINCRONIZANDO...',
      'change_path': 'ALTERAR',
      'settings': 'Configurações do Projeto',
      'git_token': 'Token Secreto do GitHub',
      'git_desc':
          'Opa! Usamos Git para manter o projeto em dia. Cole seu Token de Acesso (PAT) abaixo.',
      'git_tip_title': 'DICA PRO 💡',
      'git_help':
          'Você precisa de um "Classic Token" com a permissão "repo" ativada.',
      'git_link_text': 'GERAR TOKEN NO GITHUB',
      'footer_info': 'Tudo será sincronizado com o nosso branch master.',
      'desc_project': 'O coração do AINIMONIA. Mantenha-o atualizado!',
      'desc_godot': 'Godot 4.6 Stable - Nossa engine favorita.',
      'desc_trench': 'Fork do Trenchbroom + Conector LiveSync.',
      'desc_block': 'Fork do Blockbench + Templates de Entidade.',
      'desc_blender': 'Blender 4.5.6 LTS - Modelagem, escultura e animação',
      'desc_matmaker': 'MATMAKER - Fork do Material Maker para materiais Godot.',
      'studio_top_category': 'PRINCIPAIS',
      'studio_tools_category': 'FERRAMENTAS',
    },
  };

  static String t(String key) => _data[currentLanguage]?[key] ?? key;
}

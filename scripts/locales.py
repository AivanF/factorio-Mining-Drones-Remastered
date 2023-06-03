__author__ = 'AivanF'
__contact__ = 'projects@aivanf.com'

import re
from translinguer import Translinguer

base_path = '../Mining_Drones_Remastered'
cfg_path = base_path + '/locale'
trans = Translinguer(lang_mapper={
    'English': 'en',
    'German': 'de',
    'French': 'fr',
    'Spanish': 'es',
    'Turkish': 'tr',
    'Polish': 'pl',
    'Ukrainian': 'uk',
    'Russian': 'ru',
    'Chinese': 'zh-CN',
})


def get_settings():
    with open(base_path + '/settings.lua', 'r', encoding='utf8') as file:
        content = file.read()
    return set((
        match
        for match in re.findall(' name = "(.*)",', content)
        if '--' not in match
    ))


SETTING_NAMES = get_settings()
print(f'Extracted {len(SETTING_NAMES)} settings')


def validate_settings(trans):
    page = trans.texts['mining_drones']
    section = page['mod-setting-name']
    names_have = set(section.keys())
    names_need = SETTING_NAMES
    missed = names_need - names_have
    extra = names_have - names_need
    if missed or extra:
        print('- Problem with settings names:')
        print(f'- Missed:', '\n' + '\n'.join(missed))
        print(f'- Extra:', '\n' + '\n'.join(extra))
        raise ValueError((missed, extra))


def from_raw():
    # Used to create Google Sheets manually from raw files
    trans.load_cfg(cfg_path)
    print(trans.to_csv())


def from_remote():
    trans.load_from_gsheets(name='MD2R-Texts')
    trans.stats()
    trans.validate()
    trans.save_cache()


def from_cache():
    trans.load_cache()
    trans.stats()
    validate_settings(trans)
    trans.validate(raise_error=True)
    trans.save_cfg(cfg_path)


if __name__ == '__main__':
    from_remote()
    from_cache()
    pass

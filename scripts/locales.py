__author__ = 'AivanF'
__contact__ = 'projects@aivanf.com'

from translinguer import Translinguer

cfg_path = '../Mining_Drones_Remastered/locale'
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
    trans.validate(raise_error=True)
    trans.save_cfg(cfg_path)


if __name__ == '__main__':
    from_remote()
    from_cache()

# Окраины · результат автономного прогона

Оригинальный игровой срез «Разлома Эфира» работает как мрачный мини-прототип. Главная сцена — `res://src/world/levels/outskirts_slice.tscn`.

- У земли, кладки, скал и выжженных участков свои трипланарные PBR-материалы. В крепости и лощине расставлены четыре модели Poly Haven. Холодный свет освещает туман, тёплые факелы и Алтарь отмечают безопасный лагерь. [Источники и лицензии](../LICENSES.md)
- Две библиотеки Quaternius ведут скелет Лины через плавные переходы по 0,15 с. FBX Mixamo из папки `assets/models/lina/animations/` добавляются в библиотеку `mixamo`. Имена `Idle`, `Walk`, `Run`, `Dodge`, `Sword_Attack_1`, `Sword_Attack_2`, `Block`, `Hit_React`, `Die`, `Cast_Spell` и `Bow_Aim` связываются с соответствующими состояниями. Чтобы задействовать четыре уже поставлявшихся файла вместо клипов Quaternius, включи `prefer_mixamo_overrides` на AnimationTree Лины.
- Лощина проходится от меню до выбора у охотника. Комбо и критический удар действуют через реальные хитбоксы. Алтарь сохраняет печати и восстанавливает открытые встречи. Сгусток возвращает нераспределённый опыт до следующей смерти.
- Оконный автопрогон на Godot 4.7.2 Forward+ выполнил 84 проверок. В консоли 0 ошибок и 0 предупреждений. Для кнопок и осей использовались события геймпада Godot. [Сценарий](../tests/dark_souls_proto.gd), [лог](../captures/dark_souls_proto/verification.log)
- Кадры · [меню](../captures/dark_souls_proto/01-menu.png) · [лук](../captures/dark_souls_proto/03-bow.png) · [комбо](../captures/dark_souls_proto/04-sword-follow.png) · [отдых](../captures/dark_souls_proto/07-altar-rest.png) · [осколки](../captures/dark_souls_proto/09-recoverable-shards.png) · [финальный выбор](../captures/dark_souls_proto/10-dialogue-choice.png)

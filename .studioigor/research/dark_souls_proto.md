# Окраины · окружение и боевая петля

2026-11-25

- Poly Haven публикует раздельные карты поверхности и зависимости glTF. Скачаны 16 карт и четыре комплекта фотограмметрии. Размер и MD5 каждого файла сверены с API. Лицензии и страницы ассетов указаны в LICENSES.md. [Poly Haven API](https://polyhaven.com/our-api)
- Четыре материала используют мировую трипланарную проекцию. Нормали, шероховатость и AO импортируются с mipmap. Текстуры кладки видны под боковым светом факелов, а обожжённая земля выделяет оба разлома. [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html)
- В Forward+ оставлены ACES и SDFGI. SSAO подчёркивает контактные тени, SSIL собирает локальный отражённый свет, а три эллипсоидальных FogVolume держат туман у земли. [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html), [FogVolume](https://docs.godotengine.org/en/stable/classes/class_fogvolume.html)
- Два GLB Quaternius импортируются как AnimationLibrary. BoneMap сопоставляет кости исходного манекена с SkeletonProfileHumanoid. Движение по горизонтали ведёт CharacterBody3D, клипы передают позы и высоту таза. [Ретаргетинг в Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html), [импорт AnimationLibrary](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
- Клавиши, мышь и стандартизированные оси и кнопки геймпада проходят через InputMap. Воспроизводимый оконный тест отправляет InputEventJoypadButton и InputEventJoypadMotion. [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)

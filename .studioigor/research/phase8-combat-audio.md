# Оружие, стихии и звук Фазы 8

2026-11-25

- Крепления Godot следуют трансформации выбранной кости. Внешний путь к Skeleton3D позволяет хранить оружие отдельной сценой, сохраняя существующие настройки импорта VRM. Углы рукоятей сняты с анимаций Aim и Sword. [BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html)
- В цепи молнии проверяем расстояние и видимость от цели к цели запросом к физическому миру. Это использует ту же маску препятствий, что и проверка попадания мечом. [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)
- Короткие эффекты сгенерированы в PCM WAV. Гул и ветер зациклены через метаданные WAV. Тетива, свист, взмах, гул и хлопок пространственные. Ветер стереофонический. Хлопок взят из сборки Фазы 7. [AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html)

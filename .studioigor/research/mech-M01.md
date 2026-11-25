# M01 — бег, рывок и прицеливание · 2026-11-25

- Для столкновений и пола использовать `CharacterBody3D.move_and_slide()` в физическом кадре. [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- Обзор от третьего лица использует установленный Phantom Camera и его режим Third Person Follow. Коллизия камеры ограничена слоем геометрии. [Phantom Camera](https://phantom-camera.dev/follow-modes/third-person)
- `Engine.time_scale` замедляет симуляцию сцены и мишень. Реакция объектива вычисляется в реальном времени. При выходе восстанавливается предыдущий масштаб времени. [Godot Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale)

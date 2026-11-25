# Тактический бой на окраинах — 2026-11-25

- [QuadMesh](https://docs.godotengine.org/en/stable/classes/class_quadmesh.html) и [spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) позволяют отрисовать две шкалы одним билбордом с параметрами для каждого врага.
- [Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html) масштабирует игровой delta. Таймеры добивания, ралли и акробатики используют немасштабированный delta. Управление камерой выбирает один масштаб времени, чтобы эффекты не перезаписывали друг друга.
- [Range](https://docs.godotengine.org/en/stable/classes/class_range.html) задаёт реальные HP на HUD. Градиент рисуется поверх сегмента между текущим и потенциальным здоровьем. Взрывы искр берём из эффекта Магии Жизни.
- [Ray casting](https://docs.godotengine.org/en/latest/tutorials/physics/ray-casting.html) позволяет проверять отдельный Area3D с `collide_with_areas`. Проверка ядра ограничена фактическим участком полёта до препятствия.
- Начальные значения для прогона: 84 HP у приспешника, парирование +50% концентрации, стрела в замах +35%, спад 12%/с. Ралли возвращает до половины фактического урона по цели. Выстрел в упор — в пределах 3 м.

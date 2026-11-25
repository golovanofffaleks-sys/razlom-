# M03 — Малый Разлом · 2026-11-25

- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) позволяет двигать приспешника в физическом тике и скользить вдоль границ. Центральная площадка открыта для прямого преследования.
- [PhysicsShapeQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsshapequeryparameters3d.html) разделяет маски тел и областей. Меч и стрела по-прежнему находят физическое тело цели, затем передают урон его `HurtboxComponent`.
- [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) даёт именованное действие для удержания физической E. Каст считает реальное время, атаки и преследование — игровое, чтобы прицеливание замедляло угрозы.
- Рабочие интервалы взяты из M02: прежний манекен предупреждал за 0,65 с. Приспешник предупреждает за 0,72 с и фиксирует направление, чтобы игрок мог уйти в сторону или встретить удар блоком.

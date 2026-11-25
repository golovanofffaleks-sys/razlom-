# M02 — Лук и запасной удар мечом

Дата — 2026-11-25. Движок — Godot 4.7.2.

- Для прицела луч идёт через центр камеры, затем направление полёта вычисляется от лука к точке луча. Проекция камеры учитывает текущий угол обзора. [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#class-camera3d-method-project-ray-normal)
- Стрела — тело Godot, которое за физический тик проходит отрезок со столкновением через `move_and_collide`. Гравитация меняет скорость полёта. Опыт начисляется при фактически снятом здоровье. [PhysicsBody3D](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-move-and-collide)
- Хитбокс меча проверяет объём вдоль клинка во время активного окна. Дополнительный луч исключает цель за стеной. [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)
- Шина сохраняет публичные сигналы. Предупреждение о локальном отсутствии вызова снимается на объявлениях сигналов. [Предупреждения GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)
- Общий `BoneMap` переводит кости четырёх FBX Mixamo в профиль `SkeletonProfileHumanoid` с теми же осями, что и у VRM. Импорт нормализует высоту таза. Горизонтальное перемещение в клипах отключено, чтобы контроллер сохранял положение модели относительно коллайдера. [Ретаргетинг Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
- `BlendSpace1D` смешивает покой и бег по фактической скорости. Действия используют переходы с кроссфейдом и клипы со сроком, заданным боевым ресурсом. Замедление мира влияет на стрелу и манекен. Шкала выносливости, неуязвимость и боевые анимации используют реальные секунды. [AnimationNodeStateMachineTransition](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachinetransition.html)
- Камера движется за Линой в режиме Third Person и смотрит на точку захвата через режим Simple. [Phantom Camera Look At](https://phantom-camera.dev/look-at-modes/overview)

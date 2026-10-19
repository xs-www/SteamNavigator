

# Hull 船体

- id:String modid:hull/entity_id 
- name:String 名称
- description:String 描述
- tags:List [tag1, tag2]
- enabled:Bool
- data:Dictionary
  ```
  {
    tier:Int,
    size_tag:Enum {'small', 'medium', 'large'},
    operation_profile:Enum {'coast', 'ocean'},
    hull_mass:Int,
    purchase_price:Int,
    craft_time_hours:Int,
    materials:List [ItemDict1, ItemDict2];ItemDict {id:String, acount:Int},
    base_speed:Float,
    max_weight:Int,
    max_durability:Int,
    cargo_slots:Int,
    cabin_slots:Int,
    base_risk:Float
  },
  ```
- infomation:Dictionary
  ```
  {
    size:Float //设计长度

  }
  ```
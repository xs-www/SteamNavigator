// @static-doc
// 作用：把所选舰的视野与逐武器射程/射界转换为可绘制的圆形或扇形覆盖层。
//
// ## 契约与约束
// - 视野始终是整圆；360 度武器是圆环，普通武器以舰艏为中心显示射界扇形。
// - 侧弦炮生成左右舷两个对称扇形，扇形角度随船体当前 heading 旋转。
// - 每个已安装武器实例单独生成覆盖层，即使安装了相同武器也不合并。
// @end-static-doc

const TAU = Math.PI * 2;

export function rangeShapes(ship) {
  const shapes = [{ type: "circle", role: "vision", radius: ship.stats.vision, minRadius: 0, label: `视野 ${ship.stats.vision.toFixed(0)}` }];
  ship.stats.weapons.forEach((weapon, mountIndex) => {
    const arcRadians = Math.min(360, weapon.arc) * Math.PI / 180;
    const base = { role: "weapon", radius: weapon.range, minRadius: weapon.minRange || 0, weapon, mountIndex };
    if (weapon.kind === "broadside") {
      for (const side of [-1, 1]) {
        const center = ship.heading + side * Math.PI / 2;
        shapes.push({ ...base, type: "sector", startAngle: center - arcRadians / 2, endAngle: center + arcRadians / 2, label: side === 1 ? `${weapon.name} ${weapon.range}` : "" });
      }
    } else if (arcRadians >= TAU - 0.001) {
      shapes.push({ ...base, type: "circle", label: `${weapon.name} ${weapon.range}` });
    } else {
      shapes.push({ ...base, type: "sector", startAngle: ship.heading - arcRadians / 2, endAngle: ship.heading + arcRadians / 2, label: `${weapon.name} ${weapon.range}` });
    }
  });
  return shapes;
}

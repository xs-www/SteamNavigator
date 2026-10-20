// @static-doc
// 作用：维护默认与自定义状态机库，迁移旧版随舰战术，并解析每艘船唯一挂载的状态机。
//
// ## 契约与约束
// - default 可编辑但不可删除；舰船只保存 tacticId；删除自定义状态机时挂载回退至 default。
// @end-static-doc
import{normalizeTactic}from"./tactics.mjs";
export const DEFAULT_MACHINE_ID="default";
export function createDefaultTacticLibrary(){return[{id:DEFAULT_MACHINE_ID,name:"默认战术",builtin:true,tactic:normalizeTactic()}];}
const cleanId=(v,f)=>(String(v||f).replace(/[^a-zA-Z0-9_-]/g,"_").slice(0,48)||f);
export function normalizeTacticLibrary(value){const seen=new Set();const entries=(Array.isArray(value)?value:[]).flatMap((e,i)=>{let id=cleanId(e?.id,`tactic_${i+1}`);while(seen.has(id))id=`${id}_${i+1}`;seen.add(id);return[{id,name:String(e?.name||`战术 ${i+1}`).slice(0,40),builtin:id===DEFAULT_MACHINE_ID,tactic:normalizeTactic(e?.tactic)}]});if(!seen.has(DEFAULT_MACHINE_ID))entries.unshift(createDefaultTacticLibrary()[0]);return entries;}
export function migrateTacticalData(fleets,rawLibrary){const library=normalizeTacticLibrary(rawLibrary),ids=new Set(library.map(e=>e.id));for(const fleet of fleets)for(const ship of fleet){if(ship.tacticId&&ids.has(ship.tacticId)){delete ship.tactic;continue;}if(ship.tactic){let id=cleanId(`legacy_${ship.id}`,`legacy_${library.length+1}`);while(ids.has(id))id=`${id}_copy`;ids.add(id);library.push({id,name:`${ship.name}·迁移战术`,builtin:false,tactic:normalizeTactic(ship.tactic)});ship.tacticId=id;delete ship.tactic;}else ship.tacticId=DEFAULT_MACHINE_ID;}return library;}
export function resolveShipTactic(ship,library){return normalizeTactic(library.find(e=>e.id===ship.tacticId)?.tactic||library.find(e=>e.id===DEFAULT_MACHINE_ID)?.tactic);}
export function uniqueMachineId(library,prefix="tactic"){const ids=new Set(library.map(e=>e.id));const serial=Date.now().toString(36);let id=`${prefix}_${serial}`,n=2;while(ids.has(id))id=`${prefix}_${serial}_${n++}`;return id;}

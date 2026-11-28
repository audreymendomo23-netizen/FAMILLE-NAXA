import React from "react";
import {visualSources} from "./visual-assets.mjs";
export function Visual({name,variant="page",priority=false}){
 if(!Object.prototype.hasOwnProperty.call(visualSources,name))return null;
 return <span className={"wm-visual wm-visual-"+variant} data-wm-photo={name}><img src={"/visuals/"+name+".jpg"} alt="" loading={priority?"eager":"lazy"} decoding="async" fetchPriority={priority?"high":"auto"}/></span>;
}

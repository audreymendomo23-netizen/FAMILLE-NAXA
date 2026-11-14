import test from "node:test";import assert from "node:assert/strict";import {contrastRatio} from "../src/contrast.js";
const primaries=["#0D2E57","#052163","#0E224D","#111111","#012952","#002C98","#2058F4"];
test("white foreground meets WCAG AA 4.5:1 on all seven defined primary colors",()=>{for(const color of primaries)assert.ok(contrastRatio(color,"#FFFFFF")>=4.5,color+" primary contrast below 4.5")});
test("accent foreground choices meet WCAG AA",()=>{const pairs=[["#89B255","#111111"],["#FC7820","#111111"],["#F56202","#111111"],["#DD3A33","#000000"],["#018A44","#000000"],["#D81224","#FFFFFF"],["#FDCC1D","#111111"],["#FD6213","#111111"],["#FDA601","#111111"]];for(const [bg,fg] of pairs)assert.ok(contrastRatio(bg,fg)>=4.5,bg+" foreground contrast below 4.5")});

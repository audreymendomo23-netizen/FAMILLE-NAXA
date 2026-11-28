import {test,expect} from "@playwright/test";
import {mkdirSync} from "node:fs";
for(const [width,height] of [[390,844],[1280,900]])test("original photos and accessible responsive visual design "+width,async({page})=>{
 await page.setViewportSize({width,height});await page.emulateMedia({reducedMotion:"reduce"});await page.goto("/");
 const hero=page.locator('[data-wm-photo="home"] img');await expect(hero).toBeVisible();await expect.poll(()=>hero.evaluate(i=>i.complete&&i.naturalWidth>0)).toBe(true);
 for(const img of await page.locator(".wm-visual img").all()){await img.scrollIntoViewIfNeeded();await expect.poll(()=>img.evaluate(i=>i.complete&&i.naturalWidth>0)).toBe(true);expect(await img.evaluate(i=>({filter:getComputedStyle(i).filter,fit:getComputedStyle(i).objectFit,opacity:getComputedStyle(i).opacity}))).toEqual({filter:"none",fit:"contain",opacity:"1"})}
 expect(await page.locator("[data-wm-photo=home]").evaluate(e=>getComputedStyle(e).animationName)).toBe("none");
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 await page.evaluate(()=>scrollTo(0,0));mkdirSync("test-results",{recursive:true});await page.screenshot({path:"test-results/widemeet-visual-"+width+".png",fullPage:true});
 await page.getByRole("button",{name:"Mode nuit",exact:true}).click();await expect(page.locator("html")).toHaveAttribute("data-theme","dark");
 await page.getByRole("button",{name:"Se connecter",exact:true}).click();await expect(page.getByRole("heading",{name:"Connexion",exact:true})).toBeVisible();await expect(page.locator("[data-wm-view=signin] .wm-visual")).toHaveCount(0);await expect(page.locator("nav")).toHaveCount(0);await expect(page.getByLabel("Identifiant WideMeet")).toBeVisible();await expect(page.getByLabel("Mot de passe",{exact:true})).toBeVisible();await expect(page.getByRole("button",{name:"Se connecter",exact:true})).toBeVisible();await expect(page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);await page.screenshot({path:"test-results/widemeet-visual-signin-"+width+".png",fullPage:true});await page.getByRole("button",{name:"Retour",exact:true}).click();await expect(hero).toBeVisible();await expect(page.locator("nav")).toBeVisible();
});

import {test,expect} from "@playwright/test";
test("N0 shell responsive navigation, theme, locale and motion persistence",async({page})=>{
 await page.setViewportSize({width:320,height:700});await page.goto("/");
 await expect(page.getByRole("heading",{name:"Vos réunions, sans frontières."})).toBeVisible();
 await expect(page.getByAltText("WideMeet")).toBeVisible();
 await expect(page.locator("nav button")).toHaveCount(5);
 for(const [i,label] of ["Accueil","Agenda","Chat","Archives","Profil"].entries()){
  await page.locator("nav button").nth(i).click();
  await expect(page.locator("nav button").nth(i)).toHaveAttribute("aria-current","page");
  if(i>0)await expect(page.getByRole("heading",{name:label,exact:true})).toBeVisible();
 }
 expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
 await page.getByRole("button",{name:"Mode nuit",exact:true}).click();
 await expect(page.locator("html")).toHaveAttribute("data-theme","dark");
 await page.reload();await expect(page.locator("html")).toHaveAttribute("data-theme","dark");
 await page.getByRole("button",{name:"Options",exact:true}).click();
 await expect(page.getByRole("dialog",{name:"Options"})).toBeVisible();
 await page.getByRole("button",{name:"Paramètres ›",exact:true}).click();
 await page.getByRole("button",{name:"English",exact:true}).click();
 await expect(page.locator("html")).toHaveAttribute("lang","en");
 await page.getByRole("checkbox",{name:"Animations"}).uncheck();
 await page.reload();await expect(page.locator(".shell")).toHaveAttribute("data-motion","off");
 await expect(page.locator("html")).toHaveAttribute("lang","en");
 await page.setViewportSize({width:1440,height:900});await expect(page.getByRole("heading",{name:"Your meetings, without borders."})).toBeVisible();
 expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(1440);
});
test("public PWA shell offline without caching account APIs",async({page,context})=>{
 await page.goto("/");await page.evaluate(async()=>{await navigator.serviceWorker.ready});await page.reload();
 await expect(page.getByAltText("WideMeet")).toBeVisible();await expect.poll(()=>page.evaluate(()=>!!navigator.serviceWorker.controller)).toBe(true);
 const manifest=await (await page.request.get("/manifest.webmanifest")).json();expect(manifest.display).toBe("standalone");
 await context.setOffline(true);await page.reload();await expect(page.getByAltText("WideMeet")).toBeVisible();
 await page.getByRole("button",{name:"Mode nuit",exact:true}).click();await expect(page.locator("html")).toHaveAttribute("data-theme","dark");
 await context.setOffline(false);
});
test("no fake authentication or billing",async({page})=>{
 await page.goto("/");await page.getByRole("button",{name:"Se connecter",exact:true}).click();
 await expect(page.getByRole("heading",{name:"Connexion",exact:true})).toBeVisible();
 await expect(page.getByRole("button",{name:"Se connecter",exact:true})).toBeDisabled();
 await page.getByRole("button",{name:"Options",exact:true}).click();await expect(page.getByRole("button",{name:"Abonnements ›",exact:true})).toHaveCount(0);
});

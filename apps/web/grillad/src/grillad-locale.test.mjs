import test from 'node:test';import assert from 'node:assert/strict';import {labels,translate,localeOf} from './grillad-locale.mjs';
test('shared locale is presentation only, three locales and fallback',()=>{for(const k of ['Accueil','Ventes','Caisse','Rapports','Profil','Assistance','Langue']){assert.equal(translate(k,'fr'),k);assert.ok(labels[k][0]);assert.ok(labels[k][1]);assert.notEqual(translate(k,'en'),k)}assert.equal(localeOf('unknown'),'fr');assert.equal(translate('unknown','ff-CM'),'unknown')});

test('English price and back labels do not silently fall back to French',()=>{assert.equal(translate('Prix','en'),'Price');assert.equal(translate('Retour','en'),'Back')});

test('sign-in and common operational labels use shared vocabulary and unsupported locale stays French',()=>{for(const k of ['Connexion','Connexion professionnelle','Téléphone (+237…)','Mot de passe oublié','Ajouter l’article','Ouvrir la caisse','Points de vente']){assert.ok(labels[k],k);assert.notEqual(translate(k,'en'),k);assert.ok(translate(k,'ff-CM'))}assert.equal(translate('Accueil','invalid'),'Accueil')});

test('extended labels have English and explicit French fallback for missing Fulfulde',()=>{for(const k of ['Assistant de pilotage','Conversation assistance','Animation nocturne'])assert.notEqual(translate(k,'en'),k);for(const [k,v] of Object.entries(labels))if(v[1]===null)assert.equal(translate(k,'ff-CM'),k)});

import {readFileSync} from 'node:fs';
test('every registered key has two nonempty translations and Android uses the same mapping',()=>{const kotlin=readFileSync(new URL('../../../android/grillad/src/main/java/cm/naxa/grillad/GrilladLocale.kt',import.meta.url),'utf8');for(const [k,[en,ff]] of Object.entries(labels)){assert.ok(en?.trim(),k);assert.ok(ff?.trim(),k);assert.ok(kotlin.includes(' '+JSON.stringify(k)+' -> if(locale=="en")'+JSON.stringify(en)+' else '+JSON.stringify(ff)),k);assert.equal(translate(k,'en'),en);assert.equal(translate(k,'ff-CM'),ff)}});

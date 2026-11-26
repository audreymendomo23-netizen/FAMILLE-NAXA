import {readFileSync} from 'node:fs';
import {packagePrice} from '../../packages/billing-core/src/index.js';
const policy=JSON.parse(readFileSync(new URL('../BOOTIK_POLITIQUE_COMMERCIALE.json',import.meta.url),'utf8'));
export function quote(universe,plan,months){if(!Object.hasOwn(policy.plans,universe)||!Object.hasOwn(policy.plans[universe],plan)||!policy.allowedMonths.includes(months))throw new RangeError('unsupported_bootik_offer');const monthly=policy.plans[universe][plan];return months===1?monthly:packagePrice(monthly,months)}
export function trialEnd(activatedAt){if(!Number.isSafeInteger(activatedAt)||activatedAt<0)throw new TypeError('invalid_activation');return activatedAt+policy.trialHours*3600000}

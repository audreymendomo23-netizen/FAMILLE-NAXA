export type AppId = "kiosko" | "bootik" | "zipple" | "naxa-services" | "cotiz" | "loyable" | "naxa-hotel" | "campus237" | "naxa-security" | "grillad";
export type DomainKind="catalog"|"profile"|"inventory"|"sale"|"payment"|"subscription"|"booking"|"delivery"|"security";
export type ConflictDecision="accept"|"manual_review"|"compensate";
export function decideConflict(kind:DomainKind,expected:number,actual:number):ConflictDecision{if(expected===actual)return "accept";if(["sale","payment","subscription"].includes(kind))return "manual_review";if(kind==="inventory")return "compensate";return "manual_review"}
export type PaymentState="declared"|"captured"|"submitted"|"verified"|"rejected"|"reversed";
export type NotificationState="created"|"queued"|"sent"|"received"|"read"|"actioned"|"failed";
export interface SyncEnvelope<T=unknown>{eventId:string;appId:AppId;organizationId:string;locationId?:string;actorId:string;deviceId:string;aggregateType:DomainKind;aggregateId:string;aggregateVersion:number;deviceSequence:number;occurredAt:string;schemaVersion:1;payload:T}

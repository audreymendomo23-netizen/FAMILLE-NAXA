export function mediaAttempt(){let current=0;return {begin(){return ++current},invalidate(){++current},valid(token){return current===token}}}

import {proxyWideMeet} from "../../src/pages-proxy.mjs";
export const onRequest=({request,env})=>proxyWideMeet(request,env);

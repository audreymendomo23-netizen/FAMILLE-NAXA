// Original photo aliases; identical Git blobs, no resampling or transformations.
export const visualSources=Object.freeze({
  "home": "zz.jfif",
  "meeting": "téléchargement (6).jfif",
  "schedule": "téléchargement (3).jfif",
  "join": "téléchargement (21).jfif",
  "signin": "téléchargement (13).jfif",
  "report": "téléchargement.jfif",
  "archive": "téléchargement (4).jfif",
  "presentation": "téléchargement (8).jfif",
  "analysis": "téléchargement (5).jfif"
});
export const visualFiles=Object.freeze(Object.keys(visualSources).map(name=>"/visuals/"+name+".jpg"));
export const actionVisual=Object.freeze({new:"meeting",schedule:"schedule",join:"join",reports:"report"});
export const tabVisual=Object.freeze({home:"home",agenda:"schedule",chat:"join",archives:"archive",profile:"signin"});
export const detailVisual=Object.freeze({...actionVisual,rooms:"meeting",statistics:"analysis",polls:"presentation",tasks:"schedule",transcription:"presentation",connect:"archive",team:"meeting",company:"home",support:"signin"});

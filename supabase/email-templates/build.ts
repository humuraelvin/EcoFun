// Generates the Supabase Auth email templates (the emails with one-time codes) from the same design
// as the app emails. Run:  deno run --allow-write=. supabase/email-templates/build.ts
//
// Each template holds an English and a Kinyarwanda version; Supabase picks one using the
// `lang` value the app saves in the user's metadata ({{ .Data.lang }}).

import { button, callout, codeBox, esc, layout, p, small } from "../functions/ecofun-mailer/templates.ts";

const IS_RW = `{{ if eq (printf "%v" .Data.lang) "rw" }}`;

interface Version {
  title: string;
  preheader: string;
  emoji: string;
  body: string;
  footer: string;
}

interface AuthTemplate {
  file: string; // supabase/email-templates/<file>.html
  apiKey: string; // Management API suffix: mailer_templates_<apiKey>_content / mailer_subjects_<apiKey>
  subject: string;
  en: Version;
  rw: Version;
}

const code = (label: string) => codeBox("{{ .Token }}", label);

const templates: AuthTemplate[] = [
  {
    file: "confirm-signup",
    apiKey: "confirmation",
    subject: "Your EcoFun verification code",
    en: {
      title: "Confirm your email",
      preheader: "Enter this code in EcoFun to finish creating your account.",
      emoji: "&#127793;",
      body:
        p("Welcome to EcoFun! Enter this code in the app to confirm your email address and finish creating your account.") +
        code("Your code") +
        small("The code expires in 1 hour. If you didn't sign up for EcoFun, you can safely ignore this email."),
      footer: "You're receiving this because someone signed up for EcoFun with this email address.",
    },
    rw: {
      title: "Emeza imeyili yawe",
      preheader: "Andika iyi kode muri EcoFun urangize gufungura konti yawe.",
      emoji: "&#127793;",
      body:
        p("Murakaza neza kuri EcoFun! Andika iyi kode muri porogaramu kugira ngo wemeze imeyili yawe, urangize gufungura konti.") +
        code("Kode yawe") +
        small("Kode irangira mu isaha imwe. Niba atari wowe wiyandikishije kuri EcoFun, wirengagize iyi meyili."),
      footer: "Wakiriye iyi meyili kuko umuntu yiyandikishije kuri EcoFun akoresheje iyi meyili.",
    },
  },
  {
    file: "reset-password",
    apiKey: "recovery",
    subject: "Your EcoFun password reset code",
    en: {
      title: "Reset your password",
      preheader: "Enter this code in EcoFun, then choose a new password.",
      emoji: "&#128273;",
      body:
        p("We received a request to reset the password for your EcoFun account. Enter this code in the app, then choose a new password.") +
        code("Your reset code") +
        small("The code expires in 1 hour. If you didn't ask to reset your password, ignore this email — your password stays the same."),
      footer: "This is a security email about your EcoFun account.",
    },
    rw: {
      title: "Hindura ijambo ry'ibanga",
      preheader: "Andika iyi kode muri EcoFun, hanyuma uhitemo ijambo ry'ibanga rishya.",
      emoji: "&#128273;",
      body:
        p("Twakiriye ubusabe bwo guhindura ijambo ry'ibanga rya konti yawe ya EcoFun. Andika iyi kode muri porogaramu, hanyuma uhitemo ijambo ry'ibanga rishya.") +
        code("Kode yawe") +
        small("Kode irangira mu isaha imwe. Niba atari wowe wabisabye, wirengagize iyi meyili — ijambo ry'ibanga ryawe ntirihinduka."),
      footer: "Iyi ni meyili y'umutekano wa konti yawe ya EcoFun.",
    },
  },
  {
    file: "magic-link",
    apiKey: "magic_link",
    subject: "Your EcoFun sign-in code",
    en: {
      title: "Your sign-in code",
      preheader: "Enter this code in EcoFun to sign in.",
      emoji: "&#128075;",
      body:
        p("Enter this code in EcoFun to sign in to your account.") +
        code("Your code") +
        small("The code expires in 1 hour. If you didn't try to sign in, you can ignore this email."),
      footer: "This is a security email about your EcoFun account.",
    },
    rw: {
      title: "Kode yo kwinjira",
      preheader: "Andika iyi kode muri EcoFun winjire.",
      emoji: "&#128075;",
      body:
        p("Andika iyi kode muri EcoFun kugira ngo winjire muri konti yawe.") +
        code("Kode yawe") +
        small("Kode irangira mu isaha imwe. Niba atari wowe wagerageje kwinjira, wirengagize iyi meyili."),
      footer: "Iyi ni meyili y'umutekano wa konti yawe ya EcoFun.",
    },
  },
  {
    file: "change-email",
    apiKey: "email_change",
    subject: "Confirm your new EcoFun email",
    en: {
      title: "Confirm your new email",
      preheader: "Enter this code in EcoFun to confirm your new email address.",
      emoji: "&#9993;&#65039;",
      body:
        p(`Enter this code in EcoFun to use <strong>{{ .NewEmail }}</strong> as the email address for your account.`) +
        code("Your code") +
        small("If you didn't ask to change your email, ignore this email and your account stays as it is."),
      footer: "This is a security email about your EcoFun account.",
    },
    rw: {
      title: "Emeza imeyili nshya",
      preheader: "Andika iyi kode muri EcoFun wemeze imeyili yawe nshya.",
      emoji: "&#9993;&#65039;",
      body:
        p(`Andika iyi kode muri EcoFun kugira ngo <strong>{{ .NewEmail }}</strong> ibe imeyili ya konti yawe.`) +
        code("Kode yawe") +
        small("Niba atari wowe wasabye guhindura imeyili, wirengagize iyi meyili, konti yawe ntihinduka."),
      footer: "Iyi ni meyili y'umutekano wa konti yawe ya EcoFun.",
    },
  },
  {
    file: "reauthentication",
    apiKey: "reauthentication",
    subject: "Confirm it's you — EcoFun",
    en: {
      title: "Confirm it's you",
      preheader: "Enter this code in EcoFun to continue.",
      emoji: "&#128737;&#65039;",
      body:
        p("Enter this code in EcoFun to confirm this action on your account.") +
        code("Your code") +
        small("If you didn't ask for this code, someone may know your password — change it in EcoFun."),
      footer: "This is a security email about your EcoFun account.",
    },
    rw: {
      title: "Emeza ko ari wowe",
      preheader: "Andika iyi kode muri EcoFun ukomeze.",
      emoji: "&#128737;&#65039;",
      body:
        p("Andika iyi kode muri EcoFun kugira ngo wemeze iki gikorwa kuri konti yawe.") +
        code("Kode yawe") +
        small("Niba atari wowe wasabye iyi kode, hari ushobora kuba azi ijambo ry'ibanga ryawe — rihindure muri EcoFun."),
      footer: "Iyi ni meyili y'umutekano wa konti yawe ya EcoFun.",
    },
  },
  {
    file: "invite",
    apiKey: "invite",
    subject: "You're invited to EcoFun",
    en: {
      title: "You're invited to EcoFun",
      preheader: "Join EcoFun — three small climate steps a day for Rwanda.",
      emoji: "&#127793;",
      body:
        p("You've been invited to join EcoFun: read local environment news, answer a short quiz and do one small climate action every day.") +
        button("{{ .ConfirmationURL }}", "Accept the invitation") +
        callout("Then open the EcoFun app and sign in with this email address."),
      footer: "You're receiving this because an EcoFun admin invited this email address.",
    },
    rw: {
      title: "Watumiwe muri EcoFun",
      preheader: "Injira muri EcoFun — intambwe eshatu nto buri munsi zo kurengera ikirere.",
      emoji: "&#127793;",
      body:
        p("Watumiwe kwinjira muri EcoFun: soma amakuru y'ibidukikije yo mu Rwanda, usubize ibibazo bike kandi ukore igikorwa gito cyo kurengera ikirere buri munsi.") +
        button("{{ .ConfirmationURL }}", "Emera ubutumire") +
        callout("Hanyuma ufungure EcoFun, winjire ukoresheje iyi meyili."),
      footer: "Wakiriye iyi meyili kuko umuyobozi wa EcoFun yagutumiye.",
    },
  },
];

const render = (lang: "en" | "rw", v: Version) =>
  layout({ lang, title: esc(v.title), preheader: esc(v.preheader), emoji: v.emoji, body: v.body, footer: esc(v.footer) });

const dir = new URL(".", import.meta.url);
const manifest: Record<string, { file: string; subject: string }> = {};
for (const t of templates) {
  const html = `${IS_RW}${render("rw", t.rw)}{{ else }}${render("en", t.en)}{{ end }}\n`;
  await Deno.writeTextFile(new URL(`${t.file}.html`, dir), html);
  manifest[t.apiKey] = { file: `${t.file}.html`, subject: t.subject };
  console.log(`wrote supabase/email-templates/${t.file}.html (${(html.length / 1024).toFixed(1)} KB)`);
}
await Deno.writeTextFile(new URL("manifest.json", dir), JSON.stringify(manifest, null, 2) + "\n");
console.log("wrote supabase/email-templates/manifest.json");

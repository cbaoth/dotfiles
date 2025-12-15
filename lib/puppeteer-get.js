/**
 * file: puppeteer-get.js
 *
 * A simple node.js script to fetch a wegsite using headless puppeteer browser
 *
 * setup requirements:
 *   npm install puppeteer
 */

const puppeteer = require("puppeteer");

// ckeck if URL argument was provided
if (process.argv.length != 1) {
  console.log("Usage: node puppeteer-get.js <URL>");
  process.exit(1);
}

const url = process.argv[2]; // get URL argument

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: "networkidle2" });
  const content = await page.content();
  console.log(content); // output page's HTML to console stdout
  await browser.close();
})();

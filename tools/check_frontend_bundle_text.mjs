#!/usr/bin/env node

const baseURL = (process.env.SUB2API_BASE_URL || 'http://127.0.0.1:8081').replace(/\/+$/, '')
const terms = process.argv.slice(2).filter(Boolean)

if (terms.length === 0) {
  console.error('Usage: node tools/check_frontend_bundle_text.mjs <text> [text...]')
  console.error('Env: SUB2API_BASE_URL defaults to http://127.0.0.1:8081')
  process.exit(2)
}

async function fetchText(url) {
  const res = await fetch(url)
  if (!res.ok) {
    throw new Error(`GET ${url} failed: HTTP ${res.status}`)
  }
  return res.text()
}

function normalizeAssetPath(path, fromPath = '/') {
  if (/^https?:\/\//.test(path)) return path
  if (path.startsWith('/')) return path
  if (path.startsWith('./') || path.startsWith('../')) {
    const base = new URL(fromPath, `${baseURL}/`)
    return new URL(path, base).pathname
  }
  return `/${path.replace(/^\.?\//, '')}`
}

function assetURL(path) {
  if (/^https?:\/\//.test(path)) return path
  const normalized = normalizeAssetPath(path)
  return `${baseURL}${normalized}`
}

function unique(values) {
  return [...new Set(values)]
}

function findAssetPaths(text, fromPath = '/') {
  return unique([
    ...[...text.matchAll(/\b(?:src|href)="([^"]+\.(?:js|css))"/g)].map(match => match[1]),
    ...[...text.matchAll(/\b(?:src|href)='([^']+\.(?:js|css))'/g)].map(match => match[1]),
    ...[...text.matchAll(/["'`]((?:\/|\.\/|\.\.\/)?[^"'`]+?\.(?:js|css))["'`]/g)].map(match => match[1])
      .filter(path => path.startsWith('/') || path.startsWith('./') || path.startsWith('../') || path.startsWith('assets/'))
  ]).map(path => normalizeAssetPath(path, fromPath))
}

const indexHTML = await fetchText(`${baseURL}/`)
const pending = findAssetPaths(indexHTML)
const seenAssets = new Set()
const assetTexts = new Map()

if (pending.length === 0) {
  throw new Error(`No JS/CSS assets found in ${baseURL}/`)
}

while (pending.length > 0) {
  const path = pending.shift()
  if (seenAssets.has(path)) continue
  seenAssets.add(path)

  const url = assetURL(path)
  const text = await fetchText(url)
  assetTexts.set(url, text)

  for (const nextPath of findAssetPaths(text, path)) {
    if (!seenAssets.has(nextPath)) {
      pending.push(nextPath)
    }
  }
}

const hits = new Map(terms.map(term => [term, []]))

for (const [url, text] of assetTexts) {
  for (const term of terms) {
    if (text.includes(term)) {
      hits.get(term).push(url)
    }
  }
}

let missing = 0
for (const term of terms) {
  const urls = hits.get(term)
  if (urls.length === 0) {
    missing += 1
    console.error(`MISS ${JSON.stringify(term)}`)
    continue
  }
  console.log(`HIT  ${JSON.stringify(term)}`)
  for (const url of urls) {
    console.log(`  ${url}`)
  }
}

if (missing > 0) {
  process.exit(1)
}

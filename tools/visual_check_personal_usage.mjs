#!/usr/bin/env node

import { spawn } from 'node:child_process'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'

const baseURL = process.env.SUB2API_BASE_URL || 'http://127.0.0.1:8081'
const adminEmail = process.env.SUB2API_ADMIN_EMAIL || 'admin@sub2api.local'
const adminPassword = process.env.SUB2API_ADMIN_PASSWORD || 'admin123456'
const userEmail = process.env.SUB2API_USER_EMAIL || adminEmail
const userPassword = process.env.SUB2API_USER_PASSWORD || adminPassword
const screenshotDir = process.env.SUB2API_SCREENSHOT_DIR || tmpdir()

const forbiddenText = [
  /总消费/i,
  /total\s+cost/i,
  /billing\s+control/i,
  /计费管理/i,
  /充值/,
  /recharge/i,
  /\$/
]
const tokenText = /(^|\s)(Token|Tokens)(\s|$)|总\s*Token|令牌/i

function fail(message) {
  console.error(`失败：${message}`)
  process.exitCode = 1
}

async function requestJSON(url, options) {
  const response = await fetch(url, options)
  const text = await response.text()
  let body
  try {
    body = text ? JSON.parse(text) : null
  } catch {
    throw new Error(`${url} 返回非 JSON：${text.slice(0, 200)}`)
  }
  if (!response.ok) {
    throw new Error(`${url} 返回 HTTP ${response.status}：${text.slice(0, 300)}`)
  }
  return body
}

async function login(email, password) {
  const body = await requestJSON(`${baseURL}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  const data = body?.data ?? body
  if (!data?.access_token || !data?.user) {
    throw new Error(`登录响应缺少 access_token 或 user：${JSON.stringify(body).slice(0, 300)}`)
  }
  if (data.requires_2fa) {
    throw new Error(`${email} 需要 2FA，无法自动执行浏览器检查`)
  }
  return data
}

async function checkRunMode() {
  const body = await requestJSON(`${baseURL}/api/v1/settings/public`)
  const data = body?.data ?? body
  const mode = data?.run_mode
  if (mode !== 'personal') {
    throw new Error(`8081 run_mode 应为 personal，实际为 ${JSON.stringify(mode)}`)
  }
}

async function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser'
  ].filter(Boolean)
  for (const candidate of candidates) {
    try {
      await readFile(candidate)
      return candidate
    } catch {
      // try next candidate
    }
  }
  throw new Error('未找到 Chrome/Chromium；可通过 CHROME_BIN 指定可执行文件')
}

async function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function waitForExit(proc) {
  if (proc.exitCode !== null || proc.signalCode !== null) return
  await new Promise(resolve => {
    const timer = setTimeout(() => {
      proc.kill('SIGKILL')
      resolve()
    }, 5000)
    proc.once('exit', () => {
      clearTimeout(timer)
      resolve()
    })
  })
}

async function removeDirWithRetry(dir) {
  let lastError
  for (let i = 0; i < 20; i += 1) {
    try {
      await rm(dir, { recursive: true, force: true })
      return
    } catch (error) {
      lastError = error
      await wait(100)
    }
  }
  throw lastError
}

async function startChrome() {
  const chrome = await findChrome()
  const profileDir = await mkdtemp(path.join(tmpdir(), 'sub2api-cdp-'))
  const args = [
    '--headless=new',
    '--remote-debugging-port=0',
    `--user-data-dir=${profileDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    'about:blank'
  ]
  const proc = spawn(chrome, args, { stdio: ['ignore', 'ignore', 'pipe'] })
  let stderr = ''
  proc.stderr.on('data', chunk => {
    stderr += chunk.toString()
  })

  const portFile = path.join(profileDir, 'DevToolsActivePort')
  let port
  for (let i = 0; i < 100; i += 1) {
    try {
      const content = await readFile(portFile, 'utf8')
      port = content.trim().split('\n')[0]
      break
    } catch {
      await wait(100)
    }
  }
  if (!port) {
    proc.kill('SIGTERM')
    throw new Error(`Chrome DevTools 未启动：${stderr.slice(0, 1000)}`)
  }

  return { proc, profileDir, endpoint: `http://127.0.0.1:${port}` }
}

async function newPage(endpoint) {
  const response = await fetch(`${endpoint}/json/new?about:blank`, { method: 'PUT' })
  if (!response.ok) {
    throw new Error(`创建 CDP 页面失败：HTTP ${response.status}`)
  }
  const target = await response.json()
  return connectCDP(target.webSocketDebuggerUrl)
}

function connectCDP(url) {
  const ws = new WebSocket(url)
  let id = 0
  const pending = new Map()

  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) {
        reject(new Error(message.error.message || JSON.stringify(message.error)))
      } else {
        resolve(message.result)
      }
    }
  })

  const opened = new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true })
    ws.addEventListener('error', reject, { once: true })
  })

  async function send(method, params = {}) {
    await opened
    const callID = ++id
    ws.send(JSON.stringify({ id: callID, method, params }))
    return new Promise((resolve, reject) => {
      pending.set(callID, { resolve, reject })
    })
  }

  return {
    send,
    close: () => ws.close()
  }
}

function jsString(value) {
  return JSON.stringify(String(value))
}

async function evaluate(page, expression) {
  const result = await page.send('Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true
  })
  if (result.exceptionDetails) {
    throw new Error(`页面脚本执行失败：${JSON.stringify(result.exceptionDetails).slice(0, 500)}`)
  }
  return result.result?.value
}

async function navigate(page, url) {
  await page.send('Page.navigate', { url })
  const deadline = Date.now() + 30000
  while (Date.now() < deadline) {
    const readyState = await evaluate(page, 'document.readyState')
    if (readyState === 'complete') return
    await wait(200)
  }
  throw new Error(`页面加载超时：${url}`)
}

async function installSession(page, session) {
  await navigate(page, baseURL)
  await evaluate(page, `
    localStorage.setItem('auth_token', ${jsString(session.access_token)});
    ${session.refresh_token ? `localStorage.setItem('refresh_token', ${jsString(session.refresh_token)});` : ''}
    ${session.expires_in ? `localStorage.setItem('token_expires_at', String(Date.now() + ${Number(session.expires_in)} * 1000));` : ''}
    localStorage.setItem('auth_user', ${jsString(JSON.stringify(session.user))});
  `)
}

async function readTextWhenSettled(page, label) {
  const deadline = Date.now() + 30000
  let text = ''
  while (Date.now() < deadline) {
    text = await evaluate(page, `document.body ? document.body.innerText : ''`) || ''
    if (tokenText.test(text) && !/登录|Login|Loading/i.test(text)) {
      return text
    }
    await wait(500)
  }
  throw new Error(`${label} 未在 30 秒内出现 Token 可见文本，最后文本：${text.slice(0, 500)}`)
}

async function screenshot(page, file) {
  const result = await page.send('Page.captureScreenshot', { format: 'png', fromSurface: true })
  await writeFile(file, Buffer.from(result.data, 'base64'))
}

async function checkPage(browser, route, session, label) {
  const page = await newPage(browser.endpoint)
  try {
    await page.send('Page.enable')
    await page.send('Runtime.enable')
    await page.send('Emulation.setDeviceMetricsOverride', {
      width: 1440,
      height: 1100,
      deviceScaleFactor: 1,
      mobile: false
    })
    await installSession(page, session)
    await navigate(page, `${baseURL}${route}`)
    const text = await readTextWhenSettled(page, label)
    const screenshotPath = path.join(screenshotDir, `sub2api-${label}.png`)
    await screenshot(page, screenshotPath)

    const hits = forbiddenText
      .map(pattern => pattern.exec(text)?.[0])
      .filter(Boolean)
    if (hits.length > 0) {
      throw new Error(`${label} 出现不应可见的文本：${hits.join(', ')}`)
    }
    if (!tokenText.test(text)) {
      throw new Error(`${label} 缺少 Token 可见文本`)
    }
    console.log(`通过：${route} -> ${screenshotPath}`)
  } finally {
    page.close()
  }
}

async function main() {
  await checkRunMode()
  const adminSession = await login(adminEmail, adminPassword)
  const userSession = userEmail === adminEmail && userPassword === adminPassword
    ? adminSession
    : await login(userEmail, userPassword)

  const browser = await startChrome()
  try {
    await checkPage(browser, '/admin/usage', adminSession, 'admin-usage')
    await checkPage(browser, '/usage', userSession, 'user-usage')
  } finally {
    browser.proc.kill('SIGTERM')
    await waitForExit(browser.proc)
    await removeDirWithRetry(browser.profileDir)
  }
}

main().catch(error => {
  fail(error instanceof Error ? error.message : String(error))
})

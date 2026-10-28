/**
 * 使い方:
 * - このファイルを、対象プロジェクトの e2e ディレクトリ（`@playwright/test` 導入済み）に
 *   `layout_overflow_check.spec.ts` としてコピーして実行する。
 *   例: LAYOUT_BASE_URL=http://localhost:5173 LAYOUT_PATHS=/,/dashboard npx playwright test layout_overflow_check.spec.ts
 * - `toHaveScreenshot` によるスナップショット比較（`LAYOUT_SNAPSHOT=1`）を使う場合、
 *   初回実行時はベースライン画像が無いため `npx playwright test --update-snapshots` を実行して基準画像を作成する。
 * - html/body に `overflow-x: hidden` があると横溢れの隠蔽（禁止する応急処置）として fail する。
 *   レガシー事情で一時的に許容するなら `LAYOUT_ALLOW_ROOT_OVERFLOW_HIDDEN=1` を指定する（fail ではなく警告に格下げ）。
 */
import { test, expect } from '@playwright/test'

const DEFAULT_BASE_URL = 'http://localhost:5173'
const DEFAULT_PATHS = '/'
const DEFAULT_VIEWPORT_WIDTHS = '320,375,768,1024,1440'
const DEFAULT_TOLERANCE_PX = 1
const DEFAULT_WAIT_MS = 500
const VIEWPORT_HEIGHT = 900
const MAX_OVERFLOWING_ELEMENTS = 10
const MAX_SELECTOR_LENGTH = 120
const MAX_CLASS_COUNT_IN_SELECTOR = 3

const baseUrl = process.env.LAYOUT_BASE_URL ?? DEFAULT_BASE_URL

const targetPaths = (process.env.LAYOUT_PATHS ?? DEFAULT_PATHS)
  .split(',')
  .map((pathValue) => pathValue.trim())
  .filter((pathValue) => pathValue.length > 0)

const viewportWidths = (process.env.LAYOUT_VIEWPORTS ?? DEFAULT_VIEWPORT_WIDTHS)
  .split(',')
  .map((widthValue) => Number(widthValue.trim()))
  .filter((widthValue) => Number.isFinite(widthValue) && widthValue > 0)

const storageStatePath = process.env.LAYOUT_STORAGE_STATE
const shouldTakeSnapshot = process.env.LAYOUT_SNAPSHOT === '1'
const tolerancePx = process.env.LAYOUT_TOLERANCE_PX ? Number(process.env.LAYOUT_TOLERANCE_PX) : DEFAULT_TOLERANCE_PX
const additionalWaitMs = process.env.LAYOUT_WAIT_MS ? Number(process.env.LAYOUT_WAIT_MS) : DEFAULT_WAIT_MS
const allowRootOverflowHidden = process.env.LAYOUT_ALLOW_ROOT_OVERFLOW_HIDDEN === '1'

if (storageStatePath) {
  test.use({ storageState: storageStatePath })
}

interface OverflowingElementInfo {
  selector: string
  left: number
  right: number
  width: number
}

interface OverflowCheckResult {
  documentScrollWidth: number
  documentClientWidth: number
  rootOverflowXHidden: boolean
  overflowingElements: OverflowingElementInfo[]
}

interface OverflowCheckOptions {
  tolerancePx: number
  maxOverflowingElements: number
  maxSelectorLength: number
  maxClassCountInSelector: number
}

for (const targetPath of targetPaths) {
  for (const viewportWidth of viewportWidths) {
    test(`${targetPath} @ ${viewportWidth}px`, async ({ page }, testInfo) => {
      await page.setViewportSize({ width: viewportWidth, height: VIEWPORT_HEIGHT })
      await page.goto(`${baseUrl}${targetPath}`, { waitUntil: 'load' })
      await page.waitForTimeout(additionalWaitMs)

      const overflowCheckResult = await page.evaluate<OverflowCheckResult, OverflowCheckOptions>(
        (options) => {
          function buildElementSelector(targetElement: Element): string {
            const tagName = targetElement.tagName.toLowerCase()
            const idSelector = targetElement.id ? `#${targetElement.id}` : ''
            const classNames = Array.from(targetElement.classList).slice(0, options.maxClassCountInSelector)
            const classSelector = classNames.length > 0 ? `.${classNames.join('.')}` : ''
            const fullSelector = `${tagName}${idSelector}${classSelector}`
            return fullSelector.length > options.maxSelectorLength
              ? fullSelector.slice(0, options.maxSelectorLength)
              : fullSelector
          }

          function hasOverflowHiddenAncestor(targetElement: Element): boolean {
            let ancestorElement = targetElement.parentElement
            while (
              ancestorElement !== null &&
              ancestorElement !== document.body &&
              ancestorElement !== document.documentElement
            ) {
              const overflowXStyle = window.getComputedStyle(ancestorElement).overflowX
              if (overflowXStyle === 'auto' || overflowXStyle === 'scroll' || overflowXStyle === 'hidden') {
                return true
              }
              ancestorElement = ancestorElement.parentElement
            }
            return false
          }

          const windowInnerWidth = window.innerWidth
          const allElements = Array.from(document.querySelectorAll('*'))
          const overflowingElementCandidates: OverflowingElementInfo[] = []

          for (const element of allElements) {
            const boundingRect = element.getBoundingClientRect()
            if (boundingRect.width === 0 || boundingRect.height === 0) {
              continue
            }

            const isOverflowingRight = boundingRect.right > windowInnerWidth + options.tolerancePx
            const isOverflowingLeft = boundingRect.left < -options.tolerancePx
            if (!isOverflowingRight && !isOverflowingLeft) {
              continue
            }

            if (hasOverflowHiddenAncestor(element)) {
              continue
            }

            if (window.getComputedStyle(element).visibility === 'hidden') {
              continue
            }

            if (element.closest('[aria-hidden="true"]') !== null) {
              continue
            }

            overflowingElementCandidates.push({
              selector: buildElementSelector(element),
              left: boundingRect.left,
              right: boundingRect.right,
              width: boundingRect.width,
            })
          }

          overflowingElementCandidates.sort((elementA, elementB) => elementB.right - elementA.right)

          const rootOverflowXHidden =
            window.getComputedStyle(document.documentElement).overflowX === 'hidden' ||
            window.getComputedStyle(document.body).overflowX === 'hidden'

          return {
            documentScrollWidth: document.documentElement.scrollWidth,
            documentClientWidth: document.documentElement.clientWidth,
            rootOverflowXHidden,
            overflowingElements: overflowingElementCandidates.slice(0, options.maxOverflowingElements),
          }
        },
        {
          tolerancePx,
          maxOverflowingElements: MAX_OVERFLOWING_ELEMENTS,
          maxSelectorLength: MAX_SELECTOR_LENGTH,
          maxClassCountInSelector: MAX_CLASS_COUNT_IN_SELECTOR,
        },
      )

      await testInfo.attach('overflowing-elements', {
        body: JSON.stringify(
          {
            rootOverflowXHidden: overflowCheckResult.rootOverflowXHidden,
            overflowingElements: overflowCheckResult.overflowingElements,
          },
          null,
          2,
        ),
        contentType: 'application/json',
      })

      if (shouldTakeSnapshot) {
        const snapshotName = `${targetPath.replace(/\//g, '_') || 'root'}-${viewportWidth}px.png`
        await expect(page).toHaveScreenshot(snapshotName, { fullPage: true })
      }

      const overflowingElementsSummary = overflowCheckResult.overflowingElements
        .map(
          (elementInfo) =>
            `${elementInfo.selector} left=${elementInfo.left} right=${elementInfo.right} width=${elementInfo.width}`,
        )
        .join('\n')

      const failureMessage = [
        `横スクロールが検出されました (path=${targetPath}, viewport=${viewportWidth}px)`,
        `scrollWidth=${overflowCheckResult.documentScrollWidth} clientWidth=${overflowCheckResult.documentClientWidth}`,
        'はみ出し要素:',
        overflowingElementsSummary || '(なし)',
      ].join('\n')

      const rootOverflowHiddenMessage = [
        `html/body に overflow-x: hidden があり横溢れが隠蔽されている (path=${targetPath}, viewport=${viewportWidth}px)`,
        'layout-defense が禁止する応急処置です。LAYOUT_ALLOW_ROOT_OVERFLOW_HIDDEN=1 を指定すると警告に格下げできます。',
      ].join('\n')

      if (allowRootOverflowHidden) {
        if (overflowCheckResult.rootOverflowXHidden) {
          testInfo.annotations.push({ type: 'warning', description: rootOverflowHiddenMessage })
        }
      } else {
        expect(overflowCheckResult.rootOverflowXHidden, rootOverflowHiddenMessage).toBe(false)
      }

      expect(overflowCheckResult.documentScrollWidth, failureMessage).toBeLessThanOrEqual(
        overflowCheckResult.documentClientWidth + tolerancePx,
      )
    })
  }
}

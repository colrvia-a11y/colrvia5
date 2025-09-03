// functions/rules.js

/**
 * @typedef {Object} Answers
 * @property {string} roomType
 * @property {string} usage
 * @property {('veryBright'|'kindaBright'|'dim')} daytimeBrightness
 * @property {('cozyYellow_2700K'|'neutral_3000_3500K'|'brightWhite_4000KPlus')} bulbColor
 * @property {('loveIt'|'maybe'|'noThanks')} boldDarkerSpot
 * @property {('SherwinWilliams'|'BenjaminMoore'|'Behr'|'pickForMe')} brandPreference
 * @property {Object=} existingElements
 * @property {('yellowGoldWood'|'orangeWood'|'redBrownWood'|'brownNeutral'|'grayBrown'|'tileOrStone'|'other')=} existingElements.floorLook
 * @property {Object=} colorComfort
 * @property {('mostlySoftNeutrals'|'neutralsPlusGentleColors'|'confidentColorMoments')=} colorComfort.overallVibe
 * @property {('warmer'|'cooler'|'inBetween')=} colorComfort.warmCoolFeel
 * @property {('verySoft'|'medium'|'crisp')=} colorComfort.contrastLevel
 * @property {string[]=} colorsToAvoid
 * @property {{ mustHaves?: string[], hardNos?: string[] }=} guardrails
 */

/**
 * @typedef {Object} PaintColor
 * @property {string} name
 * @property {string} hex
 * @property {number=} LRV
 * @property {('warm'|'cool'|'neutral'|'green-gray'|'blue-gray'|'red-brown'|'gold')=} undertone
 * @property {string[]=} tags
 */

/**
 * @typedef {Object} Target
 * @property {('SherwinWilliams'|'BenjaminMoore'|'Behr')} brand
 * @property {[number,number]} anchorLRV
 * @property {[number,number]} secondaryLRV
 * @property {[number,number]} accentLRV
 * @property {('warm'|'cool'|'neutral'|'green-gray'|null)} undertoneBias
 * @property {('verySoft'|'medium'|'crisp')} contrast
 */

/**
 * @param {Answers} a
 * @returns {Target}
 */
function computeTarget(a) {
  const brand = a.brandPreference === 'pickForMe' ? pickBrandByContext(a) : a.brandPreference;

  /** @type {Record<'veryBright'|'kindaBright'|'dim',[number,number]>} */
  const baseLRV = {
    veryBright: [55, 75],
    kindaBright: [63, 80],
    dim: [70, 88],
  };

  let anchorLRV = baseLRV[a.daytimeBrightness];

  if (a.bulbColor === 'cozyYellow_2700K') anchorLRV = [anchorLRV[0] + 2, anchorLRV[1] + 2];
  if (a.bulbColor === 'brightWhite_4000KPlus') anchorLRV = [anchorLRV[0] - 2, anchorLRV[1] - 2];

  const contrast = (a.colorComfort && a.colorComfort.contrastLevel) || 'medium';

  /** @type {[number, number]} */
  const secondaryLRV =
    contrast === 'crisp' ? [85, 96] :
    contrast === 'verySoft' ? [anchorLRV[1] - 5, 95] :
    [80, 95];

  const wantsBold = a.boldDarkerSpot === 'loveIt' || (a.colorComfort && a.colorComfort.overallVibe === 'confidentColorMoments');
  const accentLRV = wantsBold ? [3, 18] : [18, 35];

  const warmCool = (a.colorComfort && a.colorComfort.warmCoolFeel) || 'inBetween';
  /** @type {Target['undertoneBias']} */
  let undertoneBias = null;
  if (warmCool === 'warmer') undertoneBias = 'warm';
  if (warmCool === 'cooler') undertoneBias = 'cool';

  switch (a.existingElements && a.existingElements.floorLook) {
    case 'yellowGoldWood': undertoneBias = 'warm'; break;
    case 'redBrownWood': undertoneBias = 'warm'; break;
    case 'grayBrown': undertoneBias = 'cool'; break;
  }

  return { brand, anchorLRV, secondaryLRV, accentLRV, undertoneBias, contrast };
}

/**
 * @param {PaintColor} c
 * @param {[number,number]} range
 */
function fitsLRV(c, range) {
  const [lo, hi] = range;
  if (c.LRV == null) return true;
  return c.LRV >= lo && c.LRV <= hi;
}

/**
 * @param {PaintColor} c
 * @param {Target['undertoneBias']} bias
 */
function fitsUndertone(c, bias) {
  if (!bias) return true;
  const u = c.undertone || 'neutral';
  return u === bias || (bias === 'warm' && u === 'green-gray');
}

/**
 * @param {PaintColor} c
 * @param {string[]=} avoid
 */
function avoidColor(c, avoid = []) {
  const lc = `${c.name} ${(c.undertone || '')}`.toLowerCase();
  return avoid.some((w) => lc.includes(w.toLowerCase()));
}

/**
 * Simple brand picker if user said "pickForMe"
 * @param {Answers} a
 */
function pickBrandByContext(a) {
  // Bias BM for cozy/warmer, SW for crisper/cooler, otherwise Behr
  const warmCool = a.colorComfort && a.colorComfort.warmCoolFeel;
  if (warmCool === 'warmer') return 'BenjaminMoore';
  if (warmCool === 'cooler') return 'SherwinWilliams';
  return 'Behr';
}

module.exports = {
  computeTarget,
  fitsLRV,
  fitsUndertone,
  avoidColor,
  pickBrandByContext,
};

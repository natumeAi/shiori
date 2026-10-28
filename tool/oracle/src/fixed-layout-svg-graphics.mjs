// SVG graphics measurements are isolated so other row records do not change.
export async function measureSvgGraphics(page) {
  return page.evaluate(() => {
    const properties = ['fill', 'fill-rule', 'fill-opacity', 'stroke', 'stroke-width',
      'stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit', 'stroke-dasharray',
      'stroke-dashoffset', 'stroke-opacity', 'opacity', 'visibility', 'display',
      'marker-start', 'marker-mid', 'marker-end', 'filter', 'overflow'];
    const matrix = m => m ? [m.a, m.b, m.c, m.d, m.e, m.f] : null;
    return {
      geometryMethod: 'SVGGraphicsElement.getBBox/getScreenCTM; fill geometry excludes stroke',
      elements: [...document.querySelectorAll('svg * , svg')].map((el, ordinal) => {
        const style = getComputedStyle(el);
        let bounds = null;
        if (typeof el.getBBox === 'function') {
          const b = el.getBBox(); bounds = [b.x, b.y, b.width, b.height];
        }
        return { ordinal, tag: el.localName, id: el.id || null, bounds,
          screenCTM: typeof el.getScreenCTM === 'function' ? matrix(el.getScreenCTM()) : null,
          clientBox: (() => { const b = el.getBoundingClientRect(); return [b.x,b.y,b.width,b.height]; })(),
          computedPaint: Object.fromEntries(properties.map(p =>
            [p, style.getPropertyValue(p).replaceAll(location.origin, '')])),
        };
      }),
    };
  });
}

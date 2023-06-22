import numberFormatter from '../../util/number-formatter'

export default function FunnelTooltip(palette, graphData, funnel) {
  return (context) => {
    const tooltipModel = context.tooltip
    const dataIndex = tooltipModel.dataPoints[0].dataIndex
    const offset = document.getElementById("funnel").getBoundingClientRect()
    let tooltipEl = document.getElementById('chartjs-tooltip')

    if (!tooltipEl) {
      tooltipEl = document.createElement('div')
      tooltipEl.id = 'chartjs-tooltip'
      tooltipEl.style.display = 'none'
      tooltipEl.style.opacity = 0
      document.body.appendChild(tooltipEl)
    }

    if (tooltipEl && offset && window.innerWidth < 768) {
      tooltipEl.style.top = offset.y + offset.height + window.scrollY + 15 + 'px'
      tooltipEl.style.left = offset.x + 'px'
      tooltipEl.style.right = null
      tooltipEl.style.opacity = 1
    }

    if (tooltipModel.opacity === 0) {
      tooltipEl.style.display = 'none'
      return
    }

    if (tooltipModel.body) {
      const currentStep = funnel.steps[dataIndex]

      tooltipEl.innerHTML = `
        <aside class="text-gray-100 flex flex-col">
          <div class="flex justify-between items-center">
            <span class="font-semibold mr-4 text-lg">${tooltipModel.title}</span>
          </div>

          <table class="min-w-full">
            <tr>
              <th>
                <span class="flex items-center mr-4">
                <div class="w-3 h-3 mr-1 rounded-full ${palette.visitorsLegendClass}"></div>
                <span>Visitors</span>
              </th>
              <td class="text-right font-bold px-4">
                <span>${numberFormatter(currentStep.visitors)}</span>
              </td>
              <td class="text-right text-sm">
                <span>${currentStep.conversion_rate}%</span>
              </td>
            </tr>
            <tr>
              <th>
                <span class="flex items-center">
                <div class="w-3 h-3 mr-1 rounded-full ${palette.dropoffLegendClass}"></div>
                <span>Drop-off</span>
                </span>
              </th>
              <td class="text-right font-bold px-4">
                <span>${numberFormatter(currentStep.dropoff)}</span>
              </td>
              <td class="text-right text-sm">
                <span>${currentStep.dropoff_percentage}%</span>
              </td>
            </tr>
          </table>
        </aside>
        `
    }
    tooltipEl.style.display = null
  }
}

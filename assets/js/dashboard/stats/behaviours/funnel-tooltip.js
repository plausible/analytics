export default function FunnelTooltip(palette, funnel) {
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
      const previousStep = (dataIndex > 0) ? funnel.steps[dataIndex - 1] : null

      tooltipEl.innerHTML = `
        <aside class="text-gray-100 flex flex-col">
          <div class="flex justify-between items-center border-b-2 border-gray-700 pb-2">
            <span class="font-semibold mr-4 text-lg">${previousStep ? `<span class="mr-2">${previousStep.label}</span>` : ""}
              <span class="text-gray-500 mr-2">→</span>
              ${tooltipModel.title}
            </span>
          </div>

          <table class="min-w-full mt-2">
            <tr>
              <th>
                <span class="flex items-center mr-4">
                  <div class="w-3 h-3 mr-1 rounded-full ${palette.visitorsLegendClass}"></div>
                  <span>
                    ${dataIndex == 0 ? "Entered the funnel" : "Visitors"}
                  </span>
                </span>
              </th>
              <td class="text-right font-bold px-4">
                <span>
                  ${dataIndex == 0 ? funnel.entering_visitors.toLocaleString() : currentStep.visitors.toLocaleString()}
                </span>
              </td>
              <td class="text-right text-sm">
                <span>
                  ${dataIndex == 0 ? funnel.entering_visitors_percentage : currentStep.conversion_rate_step}%
                </span>
              </td>
            </tr>
            <tr>
              <th>
                <span class="flex items-center">
                  <div class="w-3 h-3 mr-1 rounded-full ${palette.dropoffLegendClass}"></div>
                  <span>
                    ${dataIndex == 0 ? "Never entered the funnel" : "Dropoff"}
                  </span>
                </span>
              </th>
              <td class="text-right font-bold px-4">
                <span>${dataIndex == 0 ? funnel.never_entering_visitors.toLocaleString() : currentStep.dropoff.toLocaleString()}</span>
              </td >
              <td class="text-right text-sm">
                <span>${dataIndex == 0 ? funnel.never_entering_visitors_percentage : currentStep.dropoff_percentage}%</span>
              </td>
            </tr >
          </table >
        </aside >
      `
    }
    tooltipEl.style.display = null
  }
}

export default function FunnelTooltip(palette, funnel) {
  return (context) => {
    const tooltipModel = context.tooltip
    const dataIndex = tooltipModel.dataPoints[0].dataIndex
    const offset = document.getElementById('funnel').getBoundingClientRect()
    let tooltipEl = document.getElementById('chartjs-tooltip-funnel')

    if (!tooltipEl) {
      tooltipEl = document.createElement('div')
      tooltipEl.id = 'chartjs-tooltip-funnel'
      tooltipEl.style.display = 'none'
      tooltipEl.style.opacity = 0
      document.body.appendChild(tooltipEl)
    }

    tooltipEl.className =
      'absolute text-sm font-normal py-3 px-4 pointer-events-none rounded-md z-[100] bg-gray-950'

    if (tooltipEl && offset) {
      tooltipEl.style.opacity = 1
    }

    if (tooltipModel.opacity === 0) {
      tooltipEl.style.display = 'none'
      return
    }

    if (tooltipModel.body) {
      const currentStep = funnel.steps[dataIndex]
      const previousStep = dataIndex > 0 ? funnel.steps[dataIndex - 1] : null

      tooltipEl.innerHTML = `
        <aside class="text-gray-100 flex flex-col gap-2">
          <div class="flex items-center gap-3 font-semibold">${previousStep ? `<span>${previousStep.label}</span>` : ''}
            <span class="text-gray-400">→</span>
            ${tooltipModel.title}
          </div>
          <hr class="border-gray-750" />
          <div class="grid grid-cols-[1fr_auto_auto] items-center gap-y-1 gap-x-4">
            <span class="flex items-center gap-2">
              <span class="size-2 rounded-full ${palette.visitorsLegendClass}"></span>
              ${dataIndex == 0 ? 'Entered the funnel' : 'Visitors'}
            </span>
            <span class="text-right font-semibold">${dataIndex == 0 ? funnel.entering_visitors.toLocaleString() : currentStep.visitors.toLocaleString()}</span>
            <span class="text-right text-gray-400">${dataIndex == 0 ? funnel.entering_visitors_percentage : currentStep.conversion_rate_step}%</span>

            <span class="flex items-center gap-2">
              <span class="size-2 rounded-full ${palette.dropoffLegendClass}"></span>
              ${dataIndex == 0 ? 'Never entered the funnel' : 'Dropoff'}
            </span>
            <span class="text-right font-semibold">${dataIndex == 0 ? funnel.never_entering_visitors.toLocaleString() : currentStep.dropoff.toLocaleString()}</span>
            <span class="text-right text-gray-400">${dataIndex == 0 ? funnel.never_entering_visitors_percentage : currentStep.dropoff_percentage}%</span>
          </div>
        </aside >
      `
    }
    tooltipEl.style.display = null
  }
}

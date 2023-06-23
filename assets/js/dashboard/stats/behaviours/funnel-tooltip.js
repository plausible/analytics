import React from 'react';
import ReactDOMServer from 'react-dom/server';

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

      tooltipEl.innerHTML = ReactDOMServer.renderToStaticMarkup((
        <aside className="text-gray-100 flex flex-col">
          <div className="flex justify-between items-center border-b-2 border-gray-700 pb-2">
            <span className="font-semibold mr-4 text-lg">{previousStep ? `${previousStep.label} → ` : "→"} {tooltipModel.title}</span>
          </div>

          <table className="min-w-full mt-2">
            <tr>
              <th>
                <span className="flex items-center mr-4">
                  <div className={`w-3 h-3 mr-1 rounded-full ${palette.visitorsLegendClass}`}></div>
                  <span>
                    {dataIndex == 0 ? "Entered the funnel" : "Visitors"}
                  </span>
                </span>
              </th>
              <td className="text-right font-bold px-4">
                <span>
                  {dataIndex == 0 ? funnel.entering_visitors.toLocaleString() : currentStep.visitors.toLocaleString()}
                </span>
              </td>
              <td className="text-right text-sm">
                <span>
                  {dataIndex == 0 ? formatPercentage(funnel.entering_visitors_percentage) : formatPercentage(currentStep.conversion_rate_step)}%
                </span>
              </td>
            </tr>
            <tr>
              <th>
                <span className="flex items-center">
                  <div className={`w-3 h-3 mr-1 rounded-full ${palette.dropoffLegendClass}`}></div>
                  <span>
                    {dataIndex == 0 ? "Never entered the funnel" : "Dropoff"}
                  </span>
                </span>
              </th>
              <td className="text-right font-bold px-4">
                <span>{dataIndex == 0 ? funnel.never_entering_visitors.toLocaleString() : currentStep.dropoff.toLocaleString()}</span>
              </td >
              <td className="text-right text-sm">
                <span>{dataIndex == 0 ? formatPercentage(funnel.never_entering_visitors_percentage) : formatPercentage(currentStep.dropoff_percentage)}%</span>
              </td>
            </tr >
          </table >
        </aside >
      ))
    }
    tooltipEl.style.display = null
  }
}

const formatPercentage = (value) => {
  const decimalNumber = parseFloat(value);
  return decimalNumber % 1 === 0 ? decimalNumber.toFixed(0) : value;
}

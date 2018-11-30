import css from "../css/app.css"
import "phoenix_html"

var ctx = document.getElementById("main-graph");
var myChart = new Chart(ctx, {
  type: 'line',
  data: {
    labels: ["22 Nov", "23 Nov", "24 Nov", "25 Nov", "26 Nov", "27 Nov"],
    datasets: [{
      label: 'Pageviews',
      data: [8, 9, 11, 15, 21, 23],
      backgroundColor: 'rgba(137,182,165, 0.2)',
      borderColor: 'rgba(137,182,165)',
      borderWidth: 2,
      pointBackgroundColor: 'rgba(137,182,165)'
    }]
  },
  options: {
    legend: {
      display: false
    },
    responsive: true,
    tooltips: {
      mode: 'index',
      intersect: false,
    },
    hover: {
      mode: 'nearest',
      intersect: true
    },
    scales: {
      xAxes: [{
        display: true,
        scaleLabel: {
          display: true,
          labelString: 'Day'
        }
      }],
    }
  }
});

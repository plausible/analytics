import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../util/number-formatter'
import {parseQuery} from '../../query'

class ModalTable extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    api.get(this.props.endpoint, this.state.query, {limit: 100})
      .then((res) => this.setState({loading: false, list: res}))
  }

  showConversionRate() {
    return !!this.state.query.filters.goal
  }

  showPercentage() {
    return this.props.showPercentage && !this.showConversionRate()
  }

  label() {
    if (this.state.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return 'Visitors'
  }

  renderTableItem(tableItem) {
    const query = new URLSearchParams(window.location.search)

    Object.entries(this.props.filter).forEach((([key, valueKey]) => {
      query.set(key, tableItem[valueKey])
    }))

    return (
      <tr className="text-sm dark:text-gray-200" key={tableItem.name}>
        <td className="p-2">
          <Link className="hover:underline" to={{search: query.toString(), pathname: `/${encodeURIComponent(this.props.site.domain)}`}}>
            {this.props.renderIcon && this.props.renderIcon(tableItem)}
            {this.props.renderIcon && ' '}
            {tableItem.name}
          </Link>
        </td>
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{numberFormatter(tableItem.total_visitors)}</td>}
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(tableItem.visitors)}</td>
        {this.showPercentage() && <td className="p-2 w-32 font-medium" align="right">{tableItem.percentage}</td>}
        {this.showConversionRate() && <td className="p-2 w-32 font-medium" align="right">{numberFormatter(tableItem.conversion_rate)}%</td>}
      </tr>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    }

    if (this.state.list) {
      return (
        <>
          <h1 className="text-xl font-bold dark:text-gray-100">{this.props.title}</h1>

          <div className="my-4 border-b border-gray-300 dark:border-gray-500"></div>
          <main className="modal__content">
            <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 w-48 md:w-56 lg:w-1/3 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="left">{this.props.keyLabel}</th>
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right" >Total Visitors</th>}
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">{this.label()}</th>
                  {this.showPercentage() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">%</th>}
                  {this.showConversionRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">CR</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.list.map(this.renderTableItem.bind(this)) }
              </tbody>
            </table>
          </main>
        </>
      )
    }

    return null
  }

  render() {
    return (
      <Modal site={this.props.site} show={!this.state.loading}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(ModalTable)

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

  label() {
    return this.state.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
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
        <td className="p-2 w-32 font-medium" align="right">
          {numberFormatter(tableItem.visitors)}
          {tableItem.percentage >= 0 &&
            <span className="inline-block text-xs w-8 pl-1 text-right">({tableItem.percentage}%)</span> }
        </td>
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
                  <th
                    className="p-2 w-48 lg:w-1/2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                    align="left"
                  >
                    {this.props.keyLabel}
                  </th>
                  <th
                    // eslint-disable-next-line max-len
                    className="p-2 w-32 lg:w-1/2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400"
                    align="right"
                  >
                    {this.label()}
                  </th>
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

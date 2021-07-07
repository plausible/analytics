import React, { Fragment } from "react";
import { withRouter } from 'react-router-dom'
import Modal from './modal'
import Datepicker from '../../datepicker'
import FilterList from '../../filters'
import { FilterDropdown } from '../../filter-selector'
import { parseQuery } from '../../query'

function withQuery(WrappedComponent) {
  return class extends React.Component {
    constructor(props) {
      super(props)
      const query = parseQuery(props.location.search, props.site)
      this.state = {query}
    }

    componentDidUpdate(prevProps) {
      const {location, site} = this.props

      if (prevProps.location !== location) {
        this.setState({
          query: parseQuery(location.search, site)
        })
      }
    }

    render() {
      return <WrappedComponent query={this.state.query} {...this.props} />;
    }
  }
}

class FilterModal extends React.Component {
  renderBody() {
    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filters for {this.props.site.domain}</h1>
        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <FilterDropdown site={this.props.site} />
          <Datepicker className="mt-4 w-full" leadingText="Daterange: " site={this.props.site} query={this.props.query} />
          <FilterList className="w-full" site={this.props.site} query={this.props.query} history={this.props.history} />
        </main>
      </>
    )
  }

  render() {
    return (
      <Modal site={this.props.site} maxWidth="460px">
        { this.renderBody()}
      </Modal>
    )
  }
}

export default withRouter(withQuery(FilterModal))

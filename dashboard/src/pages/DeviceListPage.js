import React, {Component} from 'react';
import {API_URL} from '../_constants'
import moment from 'moment';
import { Link } from 'react-router-dom';

class DeviceListPage extends Component {
    constructor(props) {
        super(props);

        this.state = {
            devices: []
        }
    }

    async componentDidMount() {
        try {
            const response = await (await fetch(API_URL.FETCH_DEVICES)).json();
            this.setState({devices: response.data.devices})
        }
        catch (err) {
            console.error("Failed fetching devices:", err);
        }
    }

    render() {
        return (
            <div>
                <h3>Device List Page</h3>
                <br/>
                <br/>
                <table className="table">
                    <thead>
                        <tr>
                            <th scope="col">Device ID</th>
                            <th scope="col">Used Capacity</th>
                            <th scope="col">Total Capacity</th>
                            <th scope="col">Used Capacity Percentage</th>
                            <th scope="col">Last Updated</th>
                            <th scope="col">Created</th>
                            <th scope="col"/>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.devices.map((item, index) =>
                                <tr key={index}>
                                    <th scope="row">{item.id}</th>
                                    <td>{item.fill_level}</td>
                                    <td>{item.total_levels}</td>
                                    {item.fill_level !== undefined ? <td>{Math.round(item.fill_level / item.total_levels * 100)}%</td> : <td/>}
                                    <td>{moment(item.updated_timestamp).local().calendar()}</td>
                                    <td>{moment(item.creation_timestamp).local().calendar()}</td>
                                    <td><Link to={`/device/${item.id}`}>View</Link></td>
                                </tr>
                        )}
                    </tbody>
                </table>
            </div>
        );
    }
}

export default DeviceListPage;

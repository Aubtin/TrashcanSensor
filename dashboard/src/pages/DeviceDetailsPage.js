import React, {Component} from 'react';
import {API_URL} from "../_constants";
import moment from "moment";

class DeviceDetailsPage extends Component {
    constructor(props) {
        super(props);

        this.state = {
            device: {},
            deviceHistory: []
        }
    }

    async componentDidMount() {
        try {
            const response = await fetch(`${API_URL.FETCH_DEVICE}?deviceId=${this.props.match.params.id}`);
            if (!response.ok) {
                this.setState({device: null});
            }
            else {
                const responseJSON = await response.json();
                this.setState({device: responseJSON.data.device, deviceHistory: responseJSON.data.history});
            }
        }
        catch (err) {
            console.error("Failed fetching device details:", err);
        }
    }

    render() {
        return (
            <div>
                <h3>Device Details Page</h3>
                <br/>
                {
                    this.state.device === null ?
                        <h5>Device with ID {this.props.match.params.id} could not be found.</h5>
                        :
                        <div>
                            <h5><b>Device ID: </b>{this.state.device.id}</h5>
                            <h5><b>Total Capacity: </b>{this.state.device.total_levels}</h5>
                            <h5><b>Created: </b>{moment(this.state.device.creation_timestamp).local().calendar()}</h5>
                            <br/>
                            <br/>
                            <h4>Device History</h4>
                            <table className="table">
                                <thead>
                                <tr>
                                    <th scope="col">Device ID</th>
                                    <th scope="col">Used Capacity</th>
                                    <th scope="col">Total Capacity</th>
                                    <th scope="col">Used Capacity Percentage</th>
                                    <th scope="col">Timestamp</th>
                                </tr>
                                </thead>
                                <tbody>
                                {this.state.deviceHistory.map((item, index) =>
                                    <tr key={index}>
                                        <th scope="row">{item.id}</th>
                                        <td>{item.fill_level}</td>
                                        <td>{this.state.device.total_levels}</td>
                                        {item.fill_level !== null ? <td>{Math.round(item.fill_level /
                                            this.state.device.total_levels * 100)}%</td> : <td/>}
                                        <td>{moment(item.creation_timestamp).local().calendar()}</td>
                                    </tr>
                                )}
                                </tbody>
                            </table>
                        </div>
                }
            </div>
        );
    }
}

export default DeviceDetailsPage;

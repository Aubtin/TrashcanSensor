import React, {Component} from 'react';
import { BrowserRouter, Route, Switch } from 'react-router-dom';
import DeviceListPage from "./pages/DeviceListPage";
import DeviceDetailsPage from "./pages/DeviceDetailsPage";

class App extends Component {
    render() {
        return (
            <div>
                <h1>Trashcan Device Dashboard</h1>

                <BrowserRouter>
                    <Switch>
                        <Route exact path="/" component={DeviceListPage}/>
                        <Route path="/device/:id" component={DeviceDetailsPage}/>
                    </Switch>
                </BrowserRouter>
            </div>
        );
    }
}

export default App;

export function getBaseURL() {
    if(process.env.NODE_ENV === "production")
        return "http://54.68.34.145/";

    return "http://127.0.0.1:5000/";
}

export const API_URL = {
    FETCH_DEVICES: getBaseURL() + 'devices',
    FETCH_DEVICE: getBaseURL() + "device"
};

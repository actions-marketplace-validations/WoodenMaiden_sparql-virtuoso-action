const fsp = require('fs/promises');

const core = require('@actions/core');
const Dockerode = require("dockerode");

const Filler = require('./fillData');

const docker = new Dockerode()
const imgName = "openlink/virtuoso-opensource-7"

// watches the container stdout and wait for the ready string to be printed
function waitForVirtuosoInit(stream) {
    return new Promise((resolve, reject) => {
        stream.on('error', (data) => reject(data.toString()))
        stream.on('data', (data) => {
            console.log(data.toString())
            if (data.toString().includes('Server online at 1111')) {
                resolve();
            }
        }) 
        stream.on('end', () => { //just in case
            console.log("Ended!")          
            resolve();
        })
    });
}

// wait for pulling to stop
// https://github.com/apocas/dockerode/issues/357#issuecomment-294511810
function pull () {
    return new Promise((res, rej) => {
        docker.pull(imgName, {
           "disable-content-trust":"false",
        }, (err, stream) => {
            if (err) rej(err)
            docker.modem.followProgress(
                stream,
                (err, output) => { // on finish
                    console.log("Finished pulling image")
                    res()
                },
                (event) => {
                }// on progress
            )
        })
    })
};

async function bootstrap() {
    "use strict"

    try {
        const dba_password = core.getInput('dba-password');
        const dav_password = core.getInput('dav-password');
        const triplesInput = core.getInput('triples');
        const dbPort = core.getInput('publish-db-port');
        const srvPort = core.getInput('publish-http-server-port')
        
        await pull()        

        const container = await docker.createContainer({
            Env: [
                `DBA_PASSWORD=${dba_password}`,
                `DAV_PASSWORD=${dav_password}`,
                
                //virtuoso.ini
                `VIRT_SPARQL_DEFAULTGRAPH=http://localhost/data`
            ],
            Image: "docker.io/" + imgName,
            Tty: false,
            AttachStdout: true,
            Detach: true,
            OpenStdin: true,
            Cmd: ['start'],
            HostConfig: {
                PortBindings: {
                    "8890/tcp": [{
                        HostPort: `${srvPort}`
                    }],
                    "1111/tcp": [{
                        HostPort: `${dbPort}`
                    }]
                }
            }
        })
        await container.start()

        const stream = await container.attach({stream: true, stdout: true, stderr: true})
        await waitForVirtuosoInit(stream)
        stream.destroy('') //streams prevent program from stopping so we destroy them
        

        if (triplesInput && triplesInput.length !== 0) {
            const files = triplesInput.split(' ');
            const fillers = []

            try {
                for(let i = 0; i < files.length; ++i) {
                    const fileHandler = await fsp.open(files[i], 'r')
                    fillers.push(new Filler(files[i], fileHandler).sendData(container)) 
                }
                
                console.log("Waiting for fillers to finish")
                await Promise.all(fillers)
                console.log("finished everything!!!");
                return;
            } catch(e) {
                core.setFailed("Error when importing data from file, details: " + e);
            }
          
        }
        else console.log('No files provided')
    
    } catch (error) {
        core.setFailed(error);
    }

}

bootstrap()
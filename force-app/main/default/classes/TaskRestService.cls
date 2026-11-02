@RestResource(urlMapping='/TaskService/*')
global with sharing class TaskRestService {

    @HttpPost
    global static String createTask() {

        RestRequest req = RestContext.request;

        Task newTask = (Task) JSON.deserialize(
            req.requestBody.toString(),
            Task.class
        );

        insert newTask;

        return JSON.serialize(new Map<String, Object>{
            'message' => 'Task created successfully',
            'taskId' => newTask.Id,
            'success' => true
        });
    }
}
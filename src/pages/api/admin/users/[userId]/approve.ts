import { NextApiRequest, NextApiResponse } from "next";
import { User } from "../../../../../../backend/models"


export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    try {
        if (req.method === "PUT") {

            const formData: any = req.body;
            switch (formData.role) {
                case "ARTIST":
                    const userModel: any = new User(req, res);
                    if (userModel.user?.role !== "ADMIN") throw new Error("You are not Authentictaed");
                    await userModel.approveArtist("", formData.status);
                    break;

                default:
                    throw new Error("Role not found!");
                    break;
            }

            res.status(200).json({
                status: "success",
                message: ""
            })
        } else {
            res
                .status(403)
                .json({
                    status: "error",
                    message: "Invalid method"
                });
        }
    } catch (error: any) {
        res
            .status(500)
            .json({
                status: "error",
                message: error.message || "something went wrong."
            });
    }
}